defmodule Cvalda.Resource do

  @spec get_resource(GenServer.server, binary) :: :not_found |
                                        {binary, [{}], binary, integer}
  def get_resource(redis, uri) do
    case Redix.command(redis, ["GET", uri]) do
      {:ok, nil} -> :not_found
      {:ok, val} ->
        {headers, etag, last_fetch} = :erlang.binary_to_term(val)
        {uri, headers, etag, last_fetch}
    end
  end

  @spec set_resource(GenServer.server, binary, [{}], binary, integer) :: :ok
  def set_resource(redis, uri, headers, etag, last_fetch) do
    bin = :erlang.term_to_binary({headers, etag, last_fetch})
    :ok = Redix.command(redis, ["SET", uri, bin])
  end

  @spec fetch(binary, [{}], binary) :: :not_modified |
                                        {:ok, binary, [{}], binary} |
                                        {:error, term}
  defp fetch(uri, req_headers, etag) do
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
