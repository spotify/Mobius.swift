// Copyright (c) 2020 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Darwin

public extension EffectRouter {
    func routeCase<EffectParameters>(
        _ enumCase: @escaping (EffectParameters) -> Effect
    ) -> _PartialEffectRouter<Effect, EffectParameters, Event> {
        return routeEffects(withParameters: { effect in
            UnwrapEnum<Effect, EffectParameters>.extract(case: enumCase, from: effect)
        })
    }
}

public extension EffectRouter where Effect: Equatable {
    func routeCase(
        _ enumCase: Effect
    ) -> _PartialEffectRouter<Effect, Void, Event> {
        return routeEffects(withParameters: { effect in
            if enumCase == effect {
                return ()
            } else {
                return nil
            }
        })
    }
}

private enum UnwrapEnum<Payload, Enum> {
    static func extract<Enum, Payload>(case: (Payload) -> Enum, from root: Enum) -> Payload? {
        func extractHelp(from root: Enum) -> ([String], Payload)? {
            if let value = root as? Payload {
                var otherRoot = `case`(value)
                var root = root
                if memcmp(&root, &otherRoot, MemoryLayout<Enum>.size) == 0 {
                    return ([], value)
                }
            }
            var path: [String] = []
            var any: Any = root
            while case let (label?, anyChild)? = Mirror(reflecting: any).children.first {
                path.append(label)
                path.append(String(describing: type(of: anyChild)))
                if let child = anyChild as? Payload {
                    return (path, child)
                }
                any = anyChild
            }
            if MemoryLayout<Payload>.size == 0 {
                return (["\(root)"], unsafeBitCast((), to: Payload.self))
            }
            if Payload.self == Void.self {
                return (path, ()) as? ([String], Payload)
            }
            return nil
        }
        guard
            let (rootPath, child) = extractHelp(from: root),
            let (otherPath, _) = extractHelp(from: `case`(child)),
            rootPath == otherPath
            else { return nil }
        return child
    }
}
