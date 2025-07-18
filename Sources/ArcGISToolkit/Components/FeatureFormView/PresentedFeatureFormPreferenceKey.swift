// Copyright 2025 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import SwiftUI

/// A preference key that specifies the feature form currently presented in the `FeatureFormView` navigation stack.
struct PresentedFeatureFormPreferenceKey: PreferenceKey {
    /// A wrapper for making a feature form equatable.
    struct EquatableFeatureForm: Equatable {
        let featureForm: FeatureForm
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.featureForm === rhs.featureForm
        }
    }
    
    // MARK: PreferenceKey Conformance
    
    static let defaultValue: EquatableFeatureForm? = nil
    
    static func reduce(value: inout EquatableFeatureForm?, nextValue: () -> EquatableFeatureForm?) {
        guard let nextValue = nextValue() else { return }
        value = nextValue
    }
}
