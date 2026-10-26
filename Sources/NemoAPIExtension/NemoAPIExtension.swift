//
//  NemoAPIExtension.swift
//  NemoAPIExtension
//
//  Created by Jeongcheol Kim on 7/14/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

@_exported import NemoAPI
import Vapor

/// Maps the contract's `APIMethod` to Vapor's `HTTPMethod` so routes never restate the method.
public extension APIMethod {
    var method: Vapor.HTTPMethod {
        switch self {
        case .GET: return .GET
        case .POST: return .POST
        case .PUT: return .PUT
        case .PATCH: return .PATCH
        case .DELETE: return .DELETE
        }
    }
}

/// Converts one contract path component into the route component Vapor registers.
public extension APIPathComponent {
    var pathComponent: Vapor.PathComponent {
        switch self {
        case .path(let path):
            return .constant(path)
        case .parameter(let extractor):
            return .parameter(extractor.name)
        }
    }
}

/// Converts a whole `pathLayout` into the components a Vapor route registration expects.
public extension Array {
    func pathComponents<Param>() -> [Vapor.PathComponent] where Element == APIPathComponent<Param> {
        self.map { $0.pathComponent }
    }
}

/// Registers routes straight from `APIEndpoint` declarations, so method and path come from the contract.
public extension RoutesBuilder {
    /// Superseded by `register(_:authTarget:body:use:)`, which also enforces `requireAuth`.
    @discardableResult
    @available(*, deprecated, renamed: "register(_endpoint:authTarget:use:)")
    func register<Endpoint: APIEndpoint, Response>(
        _ endpoint: Endpoint.Type,
        use handler: @escaping @Sendable (Vapor.Request) async throws -> Response
    ) -> Vapor.Route where Response: Vapor.AsyncResponseEncodable {
        return self.on(
            Endpoint.method.method,
            Endpoint.PathParameters.pathLayout.pathComponents(),
            use: handler
        )
    }

    /// Enforces `requireAuth` against `authTarget`, a server-only `Authenticatable` kept out of the shared contract.
    /// `.strict` requires the target and answers 401 without it; `.optional` and `.none` enforce nothing,
    /// and the handler may read an optional target with `req.auth.get(_:)`.
    /// `body` chooses how the request body is read; pass `.stream` for large uploads.
    @discardableResult
    func register<Endpoint: APIEndpoint, Target: Sendable & Authenticatable, Response>(
        _ endpoint: Endpoint.Type,
        authTarget: Target.Type,
        body: HTTPBodyStreamStrategy = .collect,
        use handler: @escaping @Sendable (Vapor.Request) async throws -> Response
    ) -> Vapor.Route where Response: Vapor.AsyncResponseEncodable {
        return self.on(
            Endpoint.method.method,
            Endpoint.PathParameters.pathLayout.pathComponents(),
            body: body,
            use: { req in
                switch Endpoint.requireAuth {
                case .strict: try req.auth.require(Target.self)
                case .optional, .none: break
                }

                return try await handler(req)
            }
        )
    }
}
