import ParableCore
import SwiftUI

struct BottleDetailView: View {
    @Environment(AppModel.self) private var model
    let bottle: Bottle
    @State private var confirmingTrash = false
    @State private var dropTargeted = false

    var body: some View {
        Form {
            Section {
                if bottle.programs.isEmpty {
                    Text("Drop a Windows .exe or installer here, or choose Add Program.")
                        .foregroundStyle(.secondary)
                }
                ForEach(bottle.programs, id: \.self) { path in
                    ProgramRow(path: path, bottle: bottle)
                }
            } header: {
                HStack {
                    Text("Programs")
                    Spacer()
                    Button("Add Program…", systemImage: "plus") { model.chooseProgram(for: bottle) }
                        .buttonStyle(.borderless)
                }
            }

            Section("Tools") {
                LabeledContent("Wine Configuration") {
                    Button("Open") { model.run(["winecfg"], in: bottle) }
                }
                LabeledContent("Registry Editor") {
                    Button("Open") { model.run(["regedit"], in: bottle) }
                }
                LabeledContent("C: Drive") {
                    Button("Show in Finder") { model.openDrive(of: bottle) }
                }
                LabeledContent("Last Run Log") {
                    Button("Open") { model.openLog(of: bottle) }
                }
            }

            Section("Settings") {
                LabeledContent("DirectX 11 and 12") {
                    if model.engine(for: bottle)?.hasD3DMetal == true {
                        Text("D3DMetal installed").foregroundStyle(.secondary)
                    } else {
                        Button("Import D3DMetal…") { model.chooseD3DMetalToolkit() }
                            .disabled(model.isRunning(bottle) || model.activity != nil)
                            .help("Most modern games need Apple's D3DMetal. Download the free Game Porting Toolkit from developer.apple.com/games, open the disk image, then choose it here.")
                    }
                }
                Toggle("Retina mode", isOn: Binding {
                    bottle.retina
                } set: { enabled in
                    Task { await model.setRetina(enabled, in: bottle) }
                })
                .disabled(model.isRunning(bottle) || model.activity != nil)
                .help("Sharper picture at full display resolution. Quit the bottle's programs before changing.")
                Picker("Controller face buttons", selection: Binding {
                    bottle.environment["SDL_GAMECONTROLLER_USE_BUTTON_LABELS"] == "0" ? "position" : "label"
                } set: { layout in
                    model.setEnvironment("SDL_GAMECONTROLLER_USE_BUTTON_LABELS",
                                         to: layout == "position" ? "0" : nil, in: bottle)
                }) {
                    Text("Match the letters on the controller").tag("label")
                    Text("Match Xbox positions").tag("position")
                }
                .disabled(model.isRunning(bottle))
                .help("Only matters for Nintendo-style controllers, where A/B and X/Y sit in swapped places. Takes effect the next time the bottle's programs start.")
                Toggle("Show Metal performance HUD", isOn: environmentFlag("MTL_HUD_ENABLED"))
                Picker("Engine", selection: Binding {
                    bottle.engine
                } set: { engine in
                    model.setEngine(engine, for: bottle)
                }) {
                    ForEach(model.engines) { engine in
                        Text(engine.hasD3DMetal ? "\(engine.name) with D3DMetal" : engine.name)
                            .tag(engine.name)
                    }
                    if model.engine(for: bottle) == nil {
                        Text("\(bottle.engine) (not installed)").tag(bottle.engine)
                    }
                }
                .disabled(model.isRunning(bottle))
            }

            Section {
                Button("Move Bottle to Trash…", role: .destructive) { confirmingTrash = true }
                    .disabled(model.isRunning(bottle))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(bottle.name)
        .navigationSubtitle(model.isRunning(bottle) ? "Running" : "")
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { files, _ in
            guard let file = files.first(where: \.isFileURL) else { return false }
            model.addProgram(file, to: bottle)
            return true
        } isTargeted: {
            dropTargeted = $0
        }
        .confirmationDialog("Move “\(bottle.name)” to the Trash?", isPresented: $confirmingTrash) {
            Button("Move to Trash", role: .destructive) { model.trash(bottle) }
        } message: {
            Text("Everything installed in this bottle, including saved games stored inside it, goes with it.")
        }
    }

    /// A toggle bound to an environment variable that is either "1" or unset.
    private func environmentFlag(_ key: String) -> Binding<Bool> {
        Binding {
            bottle.environment[key] == "1"
        } set: { enabled in
            model.setEnvironment(key, to: enabled ? "1" : nil, in: bottle)
        }
    }
}

private struct ProgramRow: View {
    @Environment(AppModel.self) private var model
    let path: String
    let bottle: Bottle

    private var file: URL { URL(fileURLWithPath: path) }
    private var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var body: some View {
        HStack {
            Image(systemName: "gamecontroller")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.deletingPathExtension().lastPathComponent)
                Text(exists ? file.deletingLastPathComponent().path : "File is missing")
                    .font(.caption)
                    .foregroundStyle(exists ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Button("Remove", systemImage: "minus.circle") { model.removeProgram(path, from: bottle) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove from this list (does not delete the file)")
            Button("Run", systemImage: "play.fill") { model.run(file, in: bottle) }
                .disabled(!exists)
        }
    }
}
