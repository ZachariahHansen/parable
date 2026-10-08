import ParableCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showingNewBottle = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(model.bottles, selection: $model.selection) { bottle in
                Label {
                    Text(bottle.name)
                } icon: {
                    Image(systemName: model.isRunning(bottle) ? "play.circle.fill" : "shippingbox")
                        .foregroundStyle(model.isRunning(bottle) ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200)
            .safeAreaInset(edge: .bottom) { activityBar }
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem {
                Button("New Bottle", systemImage: "plus") { showingNewBottle = true }
                    .disabled(model.engines.isEmpty || model.activity != nil)
                    .help("Create a new Windows environment")
            }
        }
        .sheet(isPresented: $showingNewBottle) { NewBottleSheet() }
        // Pick up bottles changed outside the app, e.g. by the `parable` CLI.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .alert("Something went wrong", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder private var detail: some View {
        if model.engines.isEmpty {
            EngineSetupView()
        } else if let bottle = model.selectedBottle {
            BottleDetailView(bottle: bottle)
        } else {
            ContentUnavailableView {
                Label("No Bottles", systemImage: "shippingbox")
            } description: {
                Text("A bottle is a self-contained Windows environment for your games.")
            } actions: {
                Button("New Bottle") { showingNewBottle = true }
                    .disabled(model.activity != nil)
            }
        }
    }

    @ViewBuilder private var activityBar: some View {
        if let activity = model.activity {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(activity).font(.callout).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.bar)
        }
    }
}

/// Shown until at least one Wine engine is installed.
struct EngineSetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install an Engine").font(.largeTitle.bold())
            Text("An engine is the Wine build that runs Windows programs. Pick one to download.")
                .foregroundStyle(.secondary)
            ForEach(EnginePreset.all) { preset in
                GroupBox {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name).font(.headline)
                            Text(preset.summary).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Install") { Task { await model.install(preset) } }
                            .disabled(model.activity != nil)
                    }
                    .padding(6)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
    }
}

struct NewBottleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var engine = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            TextField("Name", text: $name, prompt: Text("games"))
            Picker("Engine", selection: $engine) {
                ForEach(model.engines) { engine in
                    Text(engine.hasD3DMetal ? "\(engine.name) (D3DMetal)" : engine.name)
                        .tag(engine.name)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .onAppear { engine = model.engines.first?.name ?? "" }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let (name, engine) = (trimmedName, engine)
                    dismiss()
                    Task { await model.createBottle(named: name, engine: engine) }
                }
                .disabled(trimmedName.isEmpty || engine.isEmpty)
            }
        }
    }
}
