// Copyright 2023 Esri
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

/// The `FeatureFormView` component enables users to edit field values of a feature using
/// pre-configured forms, either from the Web Map Viewer or the Fields Maps Designer.
///
/// ![An image of the FeatureFormView component](FeatureFormView)
///
/// Forms are currently only supported in maps. The form definition is stored
/// in the web map itself and contains a title, description, and a list of "form elements".
///
/// `FeatureFormView` supports the display of form elements created by
/// the Map Viewer or Field Maps Designer, including:
///
/// - Attachments Element - used to display and edit attachments.
/// - Field Element - used to edit a single field of a feature with a specific "input type".
/// - Group Element - used to group elements together. Group Elements
/// can be expanded, to show all enclosed elements, or collapsed, hiding
/// the elements it contains.
/// - Text Element - used to display read-only plain or Markdown-formatted text.
/// - Utility Associations Element - used to edit associations in utility networks.
///
/// A Field Element has a single input type object. The following are the supported input types:
///
/// - Barcode - machine readable data
/// - Combo Box - long list of values in a coded value domain
/// - Date/Time - date/time picker
/// - Radio Buttons - short list of values in a coded value domain
/// - Switch - two mutually exclusive values
/// - Text Area - multi-line text area
/// - Text Box - single-line text box
///
/// **Features**
///
/// - Display a form editing view for a feature based on the feature form definition defined in a web map and obtained from either an `ArcGISFeature`, `ArcGISFeatureTable`, `FeatureLayer` or `SubtypeSublayer`.
/// - Uses native SwiftUI controls for editing, such as `TextEditor`, `TextField`, and `DatePicker` for consistent platform styling.
/// - Supports elements containing Arcade expression and automatically evaluates expressions for element visibility, editability, values, and "required" state.
/// - Add, delete, or rename feature attachments.
/// - Fully supports dark mode, as do all Toolkit components.
///
/// **Behavior**
///
/// As of 200.8, FeatureFormView uses a NavigationStack internally to support browsing utility network
/// associations. As a result, a FeatureFormView requires a navigation context isolated from any app-level
/// navigation. Basic apps without navigation can continue to place a FeatureFormView where desired.
/// More complex apps using NavigationStack or NavigationSplitView will need to relocate the FeatureFormView
/// outside of that navigation context. If the FeatureFormView can be presented modally (no background
/// interaction with the map is needed), consider using a Sheet. If a non-modal presentation is needed,
/// consider placing the FeatureFormView in a Floating Panel or Inspector, on the app-level navigation container.
/// On supported platforms, WindowGroups are another alternative to consider as a FeatureFormView container.
///
/// To see it in action, try out the [Examples](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit/tree/main/Examples/Examples)
/// and refer to [FeatureFormExampleView.swift](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit/blob/main/Examples/Examples/FeatureFormExampleView.swift)
/// in the project. To learn more about using the `FeatureFormView` see the <doc:FeatureFormViewTutorial>.
///
/// - Note: In order to capture video and photos as form attachments, your application will need
/// `NSCameraUsageDescription` and, `NSMicrophoneUsageDescription` entries in the
/// `Info.plist` file.
///
/// - Since: 200.4
public struct FeatureFormView: View {
    /// The feature form currently visible in the navigation layer.
    private let presentedForm: Binding<FeatureForm?>
    
    /// The root feature form.
    private let rootFeatureForm: FeatureForm?
    
    /// The visibility of the close button.
    var closeButtonVisibility: Visibility = .automatic
    
    /// The visibility of the "save" and "discard" buttons.
    var editingButtonsVisibility: Visibility = .automatic
    
    /// A Boolean which declares whether navigation to forms for features associated via utility association form
    /// elements is disabled.
    var navigationIsDisabled = false
    
    /// The closure to perform when a ``EditingEvent`` occurs.
    var onFormEditingEventAction: ((EditingEvent) -> Void)?
    
    /// The developer configurable validation error visibility.
    var validationErrorVisibilityExternal = ValidationErrorVisibility.automatic
    
    /// Continuation information for the alert.
    @State private var alertContinuation: (willNavigate: Bool, action: () -> Void)?
    
    /// An error thrown from finish editing.
    @State private var finishEditingError: (any Error)?
    
    /// The navigation path used by the navigation stack in the root feature form view.
    @State private var navigationPath = NavigationPath()
    
    /// The internally managed validation error visibility.
    @State private var validationErrorVisibilityInternal = ValidationErrorVisibility.automatic
    
    /// Initializes a form view.
    /// - Parameters:
    ///   - featureForm: The feature form defining the editing experience.
    /// - Since: 200.8
    public init(featureForm: Binding<FeatureForm?>) {
        self.presentedForm = featureForm
        self.rootFeatureForm = featureForm.wrappedValue
    }
    
    public var body: some View {
        if let rootFeatureForm {
            NavigationStack(path: $navigationPath) {
                InternalFeatureFormView(featureForm: rootFeatureForm)
                    .navigationDestination(for: NavigationPathItem.self) { itemType in
                        switch itemType {
                        case let .form(form):
                            InternalFeatureFormView(featureForm: form)
                        case let .utilityAssociationFilterResultView(result, internalFeatureFormViewModel):
                            UtilityAssociationsFilterResultView(
                                internalFeatureFormViewModel: internalFeatureFormViewModel,
                                utilityAssociationsFilterResult: result
                            )
                            .featureFormToolbar(internalFeatureFormViewModel.featureForm)
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle(result.filter.title, subtitle: internalFeatureFormViewModel.title)
                            .onAppear {
                                formChangedAction(internalFeatureFormViewModel.featureForm)
                            }
                        case let .utilityAssociationGroupResultView(result, internalFeatureFormViewModel):
                            UtilityAssociationGroupResultView(
                                internalFeatureFormViewModel: internalFeatureFormViewModel,
                                utilityAssociationGroupResult: result
                            )
                            .featureFormToolbar(internalFeatureFormViewModel.featureForm)
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle(result.name, subtitle: internalFeatureFormViewModel.title)
                            .onAppear {
                                formChangedAction(internalFeatureFormViewModel.featureForm)
                            }
                        }
                    }
            }
            // Alert for abandoning unsaved edits
            .alert(
                (presentedForm.wrappedValue?.validationErrors.isEmpty ?? true) ? discardEditsQuestion : validationErrors,
                isPresented: alertForUnsavedEditsIsPresented,
                actions: {
                    if let presentedForm = presentedForm.wrappedValue, let (willNavigate, continuation) = alertContinuation {
                        Button(role: .destructive) {
                            presentedForm.discardEdits()
                            onFormEditingEventAction?(.discardedEdits(willNavigate: willNavigate))
                            validationErrorVisibilityInternal = .automatic
                            continuation()
                        } label: {
                            discardEdits
                        }
                        .onAppear {
                            if !presentedForm.validationErrors.isEmpty {
                                validationErrorVisibilityInternal = .visible
                            }
                        }
                        if (presentedForm.validationErrors.isEmpty) {
                            Button {
                                Task {
                                    do {
                                        try await presentedForm.finishEditing()
                                        onFormEditingEventAction?(.savedEdits(willNavigate: willNavigate))
                                        continuation()
                                    } catch {
                                        finishEditingError = error
                                    }
                                }
                            } label: {
                                saveEdits
                            }
                        }
                        Button(role: .cancel) {
                            alertForUnsavedEditsIsPresented.wrappedValue = false
                        } label: {
                            continueEditing
                        }
                    }
                },
                message: {
                    if let validationErrors = presentedForm.wrappedValue?.validationErrors,
                       !validationErrors.isEmpty {
                        Text(
                            "You have ^[\(validationErrors.count) error](inflect: true) that must be fixed before saving.",
                            bundle: .toolkitModule,
                            comment:
                                """
                                A message explaining that the indicated number
                                of validation errors must be resolved before
                                saving the feature form.
                                """
                        )
                    } else {
                        Text(
                            "Updates to the form will be lost.",
                            bundle: .toolkitModule,
                            comment:
                                """
                                A message explaining that unsaved edits will be
                                lost if the user continues to dismiss the form
                                without saving.
                                """
                        )
                    }
                }
            )
            // Alert for finish editing errors
            .alert(
                Text(
                    "The form wasn't submitted",
                    bundle: .toolkitModule,
                    comment: "The title shown when the feature form failed to save."
                ),
                isPresented: alertForFinishEditingErrorsIsPresented,
                actions: { },
                message: {
                    if let finishEditingError {
                        Text(
                            """
                            Finish editing failed.
                            \(String(describing: finishEditingError))
                            """,
                            bundle: .toolkitModule,
                            comment:
                                """
                                The message shown when a form could not be 
                                submitted with additional details.
                                """
                        )
                    } else {
                        Text(
                            "Finish editing failed.",
                            bundle: .toolkitModule,
                            comment: "The message shown when a form could not be submitted."
                        )
                    }
                }
            )
            .environment(\.closeButtonVisibility, closeButtonVisibility)
            .environment(\.editingButtonVisibility, editingButtonsVisibility)
            .environment(\.finishEditingError, $finishEditingError)
            .environment(\.formChangedAction, formChangedAction)
            .environment(\.navigationIsDisabled, navigationIsDisabled)
            .environment(\.navigationPath, $navigationPath)
            .environment(\.onFormEditingEventAction, onFormEditingEventAction)
            .environment(\.presentedForm, presentedForm)
            .environment(\.setAlertContinuation, setAlertContinuation)
            .environment(\.validationErrorVisibilityExternal, validationErrorVisibilityExternal)
            .environment(\.validationErrorVisibilityInternal, $validationErrorVisibilityInternal)
        }
    }
}

public extension FeatureFormView {
    /// Represents events that occur during the form editing lifecycle.
    /// These events notify you when the user has either saved or discarded their edits.
    /// - Since: 200.8
    enum EditingEvent {
        /// Indicates that the user has discarded their edits.
        /// - Parameter willNavigate: A Boolean value indicating whether the view will navigate after discarding.
        case discardedEdits(willNavigate: Bool)
        /// Indicates that the user has saved their edits.
        /// - Parameter willNavigate: A Boolean value indicating whether the view will navigate after saving.
        case savedEdits(willNavigate: Bool)
    }
    
    /// Sets the visibility of the close button on the form.
    /// - Parameter visibility: The visibility of the close button.
    /// - Since: 200.8
    func closeButton(_ visibility: Visibility) -> Self {
        var copy = self
        copy.closeButtonVisibility = visibility
        return copy
    }
    
    /// Sets the visibility of the save and discard buttons on the form.
    /// - Parameter visibility: The visibility of the save and discard buttons.
    /// - Since: 200.8
    func editingButtons(_ visibility: Visibility) -> Self {
        var copy = self
        copy.editingButtonsVisibility = visibility
        return copy
    }
    
    /// Sets whether navigation to forms for features associated via utility association form
    /// elements is disabled.
    ///
    /// Use this modifier to conditionally disable navigation into other forms.
    /// - Parameter disabled: A Boolean value that determines whether navigation is disabled. Pass `true` to disable navigation; otherwise, pass `false`.
    /// - Since: 200.8
    func navigationDisabled(_ disabled: Bool) -> Self {
        var copy = self
        copy.navigationIsDisabled = disabled
        return copy
    }
    
    /// Sets a closure to perform when a form editing event occurs.
    /// - Parameter action: The closure to perform when the form editing event occurs.
    /// - Since: 200.8
    func onFormEditingEvent(perform action: @escaping (EditingEvent) -> Void) -> Self {
        var copy = self
        copy.onFormEditingEventAction = action
        return copy
    }
}

extension FeatureFormView {
    /// A Boolean value indicating whether the finish editing error alert is presented.
    var alertForFinishEditingErrorsIsPresented: Binding<Bool> {
        Binding {
            finishEditingError != nil
        } set: { newIsPresented in
            if !newIsPresented {
                finishEditingError = nil
            }
        }
    }
    
    /// A Boolean value indicating whether the unsaved edits alert is presented.
    var alertForUnsavedEditsIsPresented: Binding<Bool> {
        Binding {
            alertContinuation != nil
        } set: { newIsPresented in
            if !newIsPresented {
                alertContinuation = nil
            }
        }
    }
    
    /// The closure to perform when the presented feature form changes.
    ///
    /// - Note: This action has the potential to be called under four scenarios. Whenever an
    /// ``InternalFeatureFormView`` appears (which can happen during forward
    /// or reverse navigation) and whenever a ``UtilityAssociationGroupResultView`` appears
    /// (which can also happen during forward or reverse navigation). Because those two views (and the
    /// intermediate ``UtilityAssociationsFilterResultView`` are all considered to be apart of
    /// the same ``FeatureForm`` make sure not to over-emit form handling events.
    var formChangedAction: (FeatureForm) -> Void {
        { featureForm in
            if let presentedForm = presentedForm.wrappedValue {
                if featureForm.feature.globalID != presentedForm.feature.globalID {
                    self.presentedForm.wrappedValue = featureForm
                    validationErrorVisibilityInternal = .automatic
                }
            }
        }
    }
    
    /// A closure used to set the alert continuation.
    var setAlertContinuation: (Bool, @escaping () -> Void) -> Void {
        { willNavigate, continuation in
            alertContinuation = (willNavigate: willNavigate, action: continuation)
        }
    }
    
    // MARK: Localized text
    
    var continueEditing: Text {
        .init(
            "Continue Editing",
            bundle: .toolkitModule,
            comment: "A label for a button to continue editing the feature form."
        )
    }
    
    var discardEdits: Text {
        .init(
            "Discard Edits",
            bundle: .toolkitModule,
            comment: "A label for a button to discard unsaved edits."
        )
    }
    
    var discardEditsQuestion: Text {
        .init(
            "Discard Edits?",
            bundle: .toolkitModule,
            comment: "A question asking if the user would like to discard their unsaved edits."
        )
    }
    
    var saveEdits: Text {
        .init(
            "Save Edits",
            bundle: .toolkitModule,
            comment: "A label for a button to save edits."
        )
    }
    
    var validationErrors: Text {
        .init(
            "Validation Errors",
            bundle: .toolkitModule,
            comment: "A label indicating the feature form has validation errors."
        )
    }
}
