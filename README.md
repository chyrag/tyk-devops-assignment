# Platform Engineer / Devops role interview assignment task

The repo contains a simple HTTP request & response service built in Go,
similar in functionality to [httpbin](https://httpbin.org).
This is only a base repo which you're expected to fork  and make any
changes according to the instructions provided to you separately,
and is not fit for any other particular purpsose.

This implementation only support basic functionalitites limited to:

- Basic Request Inspection
- HTTP Methods
- AUTH (Basic auth, Digest auth and bearer token)
- HTTP Status Codes
- Delayed response.

## Building and testing

There's a provided Makefile with build and test targets included.
Please use `make build` to build the binary,
and `make test` to execute the unit tests.

To build and run the binary with default options, use `make run`


## API Endpoints

### HTTP Methods

These endpoints return information about the request including
method, headers, query parameters, body, and origin IP.

- `GET /get`
- `POST /post`
- `PUT /put`
- `PATCH /patch`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`

### Request Inspection

#### `GET /headers`

Returns all request headers.
#### `GET /ip`

Returns the origin IP address.

#### `GET /user-agent`

Returns the User-Agent header.
### Status Codes

#### `GET /status/{code}`

Returns the specified HTTP status code.

```bash
# Return 404 Not Found
curl http://localhost:8080/status/404

# Return 200 OK
curl http://localhost:8080/status/200

# Return 500 Internal Server Error
curl http://localhost:8080/status/500
```

#### Weighted Random Status Codes

Return different status codes based on probability weights.

```bash
# 90% chance of 200, 10% chance of 500
curl http://localhost:8080/status/200:0.9,500:0.1

# 50% chance of 200, 50% chance of 404
curl http://localhost:8080/status/200:0.5,404:0.5
```

### Response Delays

#### `GET /delay/{seconds}`

Delays the response for the specified number of seconds (max 10 seconds).

```bash
# Delay for 2 seconds
curl http://localhost:8080/delay/2

# Delay for 5 seconds
curl http://localhost:8080/delay/5
```

### Authentication

#### `GET /basic-auth/{user}/{passwd}`

Prompts for HTTP Basic Authentication with the specified username and password.

```bash
# Successful authentication
curl -u user:passwd http://localhost:8080/basic-auth/user/passwd

# Failed authentication (wrong credentials)
curl -u user:wrong http://localhost:8080/basic-auth/user/passwd
```

#### `GET /bearer`

Expects Bearer token authentication.

```bash
# With token
curl -H "Authorization: Bearer my-secret-token" http://localhost:8080/bearer

# Without token
curl http://localhost:8080/bearer
```

#### `GET /digest-auth/{qop}/{user}/{passwd}`

Prompts for HTTP Digest Authentication (simplified digest auth implementation).

```bash
# Using curl's digest auth support
curl --digest -u user:passwd http://localhost:8080/digest-auth/auth/user/passwd
```
