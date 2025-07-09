// Copyright 2024 Esri
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

/// A view for a read only field form element.
struct ReadOnlyInput: View {
    /// An identity for the displayed text. A new identity is generated when the element's value changes.
    @State private var id = UUID()
    
    /// The element the input belongs to.
    let element: FieldFormElement
    
    var body: some View {
        Group {
            if element.isMultiline {
                modifiedText
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal) {
                    modifiedText
                }
            }
        }
        .onValueChange(of: element) { _, _ in
            id = UUID()
        }
    }
    
    /// The text to display for the element's current value with read-only modifiers.
    var modifiedText: some View {
        text
            .accessibilityIdentifier("\(element.label) Read Only Input")
            .fixedSize(horizontal: false, vertical: true)
            .id(id)
            .lineLimit(element.isMultiline ? nil : 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .textSelection(.enabled)
    }
    
    /// The text to display for the element's current value.
    var text: Text {
        switch element.value {
        case nil:
            Text(verbatim: "--")
        case let date as Date:
            if let input = element.input as? DateTimePickerFormInput, input.includesTime {
                Text(date, format: .dateTime)
            } else {
                Text(date, format: .dateTime.day().month().year())
            }
        default:
            Text(element.formattedValue)
        }
    }
}
