# Cvalda

[![Cvalda - Björk](http://img.youtube.com/vi/-15u6J_PmT8/0.jpg)][cvalda-vid]


Regularly checks HTTP resources for updates and pushes updated ones to a messege
queue.

## Building

Use `exrm` to build releses for Cvalda:

```bash
$ mix get.deps
$ mix release
```

For more details on how to do hot upgrades/downgrades or deployments in general,
check out [exrm documentations](https://exrm.readme.io/docs).

## How it works

Cvalda keeps a list of resources, required headers, latest etag and last time
it checked that resource for updates. Other applications communicate with
Cvalda in shape of a resource information queue in which they specify which
resources they want (URI) and what headers are required to fetch that resource.

Cvalda instances keep track of list of resources and try to make sure all of
them are checked regularly. Cvalda tries its best to keep track of latest etag
header and use it to make sure it doesn't spam clients with non-update updates.

If Cvalda fetched a resource and got something it considered new, it will
dispatch the URI, response header, response body, and request time to clients.

Updates are broadcasted to a topic exchange, with routing\_key formed by
removing schema, replacing dots in each segment of URI with underscores and
replacing forward slash with dot e.g. `graph_facebook_com.act_12345.adsets`.
This way clients can pick an choose resources that are more interesting to them.

## Assumptions

A client application that connects to Cvalda should have these in mind:

### Resources

Cvalda is build to handle standard HTTP resources. This means it delibratly
only handles GET verb. It also assumes only one resource is specified by a
unified resource identifier.

### Client behaviour

Clients should handle some duplicate items in updated queue. An example of this
is the case when a new client connects to Cvalda and needs to get an initial
set of data. In this case that client starts addind its resources to watchlist
and forcing Cvalda to update which would result in all clients receiving an
update of those resources. Clients can use etags or any other case specific
logic (looking at data or other headers) if this can be of any problem.

## Internals

Watchlist checks regularly in a Redis sorted set for jobs with scores above
current timestamp. If it found any, re-schedules them for 60 seconds in future
and pushes job names to a task list. Several workers are left poping (in
blocking mode) from the task list so they will start request instantly.


[cvalda-vid]: https://www.youtube.com/watch?v=-15u6J_PmT8 "Cvalda - Björk"
