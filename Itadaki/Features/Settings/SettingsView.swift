import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.modelKey) private var model = ClaudeMenuAnalyzer.defaultModel
    @AppStorage(AppSettings.bahtPer100YenKey) private var bahtPer100Yen = 0.0
    @AppStorage(AppSettings.stripsKey) private var strips = AppSettings.defaultStrips
    @AppStorage(AppSettings.effortKey) private var effort = AnalysisEffort.low.rawValue
    @AppStorage(AppSettings.sampleModeKey) private var sampleMode = false
    /// True when the user chose to type a model id that is not in the list.
    @State private var customModel = false

    private static let customTag = "custom"

    /// Picker selection: a known model id, or `customTag` for anything else.
    private var modelChoice: Binding<String> {
        Binding(
            get: {
                let known = ClaudeMenuAnalyzer.knownModels.contains { $0.id == model }
                return customModel || !known ? Self.customTag : model
            },
            set: { choice in
                customModel = choice == Self.customTag
                if !customModel { model = choice }
            })
    }
    @State private var apiKey = ""
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text("เก็บใน Keychain ของเครื่องนี้เท่านั้น สร้าง key ได้ที่ platform.claude.com")
                }

                Section {
                    Picker("โมเดล", selection: modelChoice) {
                        ForEach(ClaudeMenuAnalyzer.knownModels, id: \.id) { known in
                            Text(known.name).tag(known.id)
                        }
                        Text("กำหนดเอง").tag(Self.customTag)
                    }
                    if modelChoice.wrappedValue == Self.customTag {
                        TextField("model id", text: $model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Picker("ระดับการคิด", selection: $effort) {
                        Text("เร็ว").tag(AnalysisEffort.low.rawValue)
                        Text("ปกติ").tag(AnalysisEffort.medium.rawValue)
                        Text("ละเอียด").tag(AnalysisEffort.high.rawValue)
                    }
                } header: {
                    Text("การอ่านเมนู")
                } footer: {
                    Text(
                        "Sonnet 5.5 เหมาะกับเมนูทั่วไป ถ้าเป็นลายมือหรืออ่านยาก ลองเพิ่มระดับการคิดก่อน แล้วค่อยเปลี่ยนเป็น Opus 5.5 (ราคาราว 2 เท่า) หรือ Fable 5.2 (ราว 4 เท่าและช้ากว่า) ส่วน Haiku 5.5 ถูกและเร็วที่สุด เหมาะกับเมนูตัวพิมพ์ชัด ๆ"
                    )
                }

                Section {
                    HStack {
                        Text("100 เยน =")
                        TextField("เช่น 22.5", value: $bahtPer100Yen, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("บาท")
                    }
                } header: {
                    Text("อัตราแลกเปลี่ยน")
                } footer: {
                    Text("ใส่ 0 ถ้าไม่ต้องการแสดงราคาเป็นบาท")
                }

                Section {
                    Picker("การแบ่งรูป", selection: $strips) {
                        Text("ไม่แบ่ง").tag(1)
                        Text("2 ส่วน").tag(2)
                        Text("3 ส่วน").tag(3)
                    }
                } footer: {
                    Text("แบ่งรูปเป็นส่วนก่อนส่งอ่าน ยิ่งแบ่งมาก ตัวหนังสือเล็กยิ่งอ่านออก แต่ค่า API ต่อรูปเพิ่มตามจำนวนส่วน")
                }

                Section {
                    Toggle("โหมดตัวอย่าง", isOn: $sampleMode)
                } footer: {
                    Text("แสดงเมนูตัวอย่างโดยไม่เรียก API ใช้ทดสอบหน้าจอ")
                }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("ตั้งค่า")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { save() }
                }
            }
            .alert("บันทึก API key ไม่สำเร็จ", isPresented: $saveFailed) {
                Button("ตกลง", role: .cancel) {}
            }
            .onAppear { apiKey = KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "" }
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainStore.set(trimmed, for: KeychainStore.apiKeyAccount) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

#Preview {
    SettingsView()
}
