defmodule Cvalda.Resource do
  @spec fetch(binary, [{}], binary) :: :not_modified |
                                        {:ok, binary, [{}], binary} |
                                        {:error, term}
  def fetch(uri, req_headers, etag) do
    req_headers = set_etag(req_headers, etag)
    res = :httpc.request(:get, {uri, req_headers},
                          [timeout: 10, connect_timeout: 15],
                          [sync: true, body_format: :binary])
    case res do
      {:ok, {_, 304, _}, _, _} ->
        :not_modified
      {:ok, {_, code, _}, headers, body} when code >= 200 and code < 300 ->
        etag = case get_etag(headers) do
          :no_etag -> ""
          e -> e
        end
        {:ok, etag, headers, body}
      {:ok, {_, code, _}, _, _} ->
        {:error, {:http_error, code}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec set_etag([{}], binary) :: [{}]
  defp set_etag(headers, etag) do
    remove_conditionals(headers, []) ++ [{"If-None-Match", etag}]
  end

  defp remove_conditionals([{field, _} | rest], acc)
            when field in ["If-None-Match", "If-Modified-Since"] do
    remove_conditionals(rest, acc)
  end
  defp remove_conditionals([head | rest], acc) do
    remove_conditionals(rest, acc ++ [head])
  end
  defp remove_conditionals([], acc) do
    acc
  end

  @spec get_etag([{}]) :: :no_etag | binary
  defp get_etag([{"ETag", etag}| _]) do
    etag
  end
  defp get_etag([_| r]) do
    get_etag(r)
  end
  defp get_etag([]) do
    :no_etag
  end
end
