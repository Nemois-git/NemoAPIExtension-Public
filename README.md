# NemoAPIExtension

[Vapor](https://vapor.codes) integration for [NemoAPI](https://github.com/Nemois-git/NemoAPI-Public).

NemoAPI declares an HTTP API contract as types. NemoAPIExtension lets a Vapor server register routes
straight from those declarations: the HTTP method and the path (constants and named parameters) come from
the endpoint, and the endpoint's authentication requirement is enforced for you. The server never restates
what the contract already says, so the two cannot drift apart.

The package re-exports NemoAPI, so a single `import NemoAPIExtension` gives you both.

## Requirements

- Swift 6.1 or later
- Vapor 4.115 or later
- NemoAPI 0.2 or later (resolved automatically)

It runs wherever Vapor 4 runs.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Nemois-git/NemoAPIExtension-Public.git", from: "0.2.0"),
],
targets: [
    .target(name: "YourServer", dependencies: [
        .product(name: "NemoAPIExtension", package: "NemoAPIExtension-Public"),
    ]),
]
```

> `from: "0.2.0"` allows any version up to (but excluding) `1.0.0`. While the package is `0.x`, a minor
> version can contain source-breaking changes; use `.upToNextMinor(from: "0.2.0")` to stay on `0.2.x`.

## What it adds

| API | Purpose |
|---|---|
| `RoutesBuilder.register(_:authTarget:body:use:)` | Registers an endpoint's route and enforces its `requireAuth`. |
| `APIMethod.method` | The matching Vapor `HTTPMethod`. |
| `APIPathComponent.pathComponent` | `.constant(...)` for a fixed segment, `.parameter(name)` for a parameter. |
| `[APIPathComponent].pathComponents()` | A whole `pathLayout` as Vapor path components. |

`register` returns the created `Route` (`@discardableResult`), so you can still chain Vapor route modifiers.

## Quick start

The contract is declared once, in a module the client and the server both import:

```swift
import NemoAPIExtension

struct Article: Codable, Sendable {
    let id: Int
    let title: String
}

struct ArticlePath: APIPathParameters {
    var id: Int

    static var pathLayout: [APIPathComponent<ArticlePath>] {
        [.path("articles"), .parameter(.init("id", \.id))]
    }
}

struct ArticleQuery: APIQuery {
    var language: String?
}

struct GetArticleEndpoint: APIEndpoint {
    typealias ResponseDTO = Article
    typealias Query = ArticleQuery
    typealias PathParameters = ArticlePath

    static let requireAuth: RequireAuth = .strict
    static let method: APIMethod = .GET
}
```

On the server, make the response type a Vapor `Content`, define the model that authenticates requests, and
register the endpoint:

```swift
import NemoAPIExtension
import Vapor

extension Article: Content {}

struct User: Authenticatable, Sendable {
    let id: UUID
}

struct ArticleController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.register(GetArticleEndpoint.self, authTarget: User.self, use: get)
    }

    @Sendable
    func get(req: Request) async throws -> Article {
        guard let id = req.parameters.get("id", as: Int.self) else { throw Abort(.badRequest) }
        let query = try req.query.decode(GetArticleEndpoint.Query.self)
        return Article(id: id, title: query.language ?? "default")
    }
}
```

This registers `GET /articles/:id`. The parameter name (`id`) is the name you gave in
`.parameter(.init("id", \.id))`, so read it back with `req.parameters.get("id", as:)`.

## Authentication

`authTarget` is the `Authenticatable` type the request is checked against. It is a parameter of `register`,
not part of the endpoint, so server-only models never leak into the shared contract.

What happens is decided by the endpoint's `requireAuth`:

| `requireAuth` | Behavior |
|---|---|
| `.strict` | Calls `req.auth.require(Target.self)`; the request is rejected with 401 when the target is missing. |
| `.optional` | Nothing is enforced. The handler may call `req.auth.get(Target.self)` to read the target when present. |
| `.none` | Authentication is irrelevant; nothing is enforced. |

The extension only enforces the requirement. Something else has to authenticate the request first: install
your own authenticator middleware on the route group so that `req.auth` is populated before the handler runs.

## Request bodies

By default the whole body is collected before your handler runs. For large uploads, ask Vapor to stream it:

```swift
routes.register(UploadEndpoint.self, authTarget: User.self, body: .stream, use: upload)
```

## Query decoding and dates

`req.query.decode(Endpoint.Query.self)` decodes the query with Vapor's URL decoder. Two details matter when
the client builds queries with NemoAPI:

- **Dates.** NemoAPI sends `Date` values as seconds since 1970 by default, which is what Vapor's default
  query decoder reads. If a query type overrides `dateEncoding` to `.iso8601`, configure the decoder to
  match, for example in `configure.swift`:

  ```swift
  ContentConfiguration.global.use(
      urlDecoder: URLEncodedFormDecoder(configuration: .init(dateDecodingStrategy: .iso8601))
  )
  ```

  Vapor's built-in strategies are seconds since 1970 and ISO 8601 without fractional seconds. The
  millisecond and fractional-second encodings need a `.custom` strategy on the server.
- **`+`.** Vapor reads `+` in a query as a space, while NemoAPI leaves `+` literal in the items it produces.
  See NemoAPI's notes if your values may contain `+`.

## Deprecated

`register(_:use:)` (without `authTarget`) is deprecated. It registers the route but does not enforce
`requireAuth`; use `register(_:authTarget:body:use:)`.

## Development

```sh
swift build
```

## License

NemoAPIExtension is available under the MIT License. See [LICENSE](LICENSE).
