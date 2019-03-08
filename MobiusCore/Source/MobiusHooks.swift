// Copyright (c) 2019 Spotify AB.
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

import Foundation

/// Adds a hook-in point for handling fatal errors when using Mobius. Fatal errors are
/// programmer mistakes; incorrect usage of Mobius APIs. The default behaviour is to
/// crash the application through invoking the `defaultErrorHandler` function defined in this
/// class. If that is not the desired behaviour, you can override it through the `setErrorHandler`
/// method.
public enum MobiusHooks {
    public typealias ErrorHandler = (String, StaticString, UInt) -> Void

    private static var errorHandler: ErrorHandler = MobiusHooks.defaultErrorHandler

    public static func setErrorHandler(_ newErrorHandler: @escaping ErrorHandler) {
        errorHandler = newErrorHandler
    }

    public static func setDefaultErrorHandler() {
        errorHandler = defaultErrorHandler
    }

    static func onError(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
        errorHandler(message, file, line)
    }

    public static func defaultErrorHandler(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
        Thread.callStackSymbols.forEach { (symbol: String) in
            print(symbol)
        }
        fatalError(message, file: file, line: line)
    }
}
