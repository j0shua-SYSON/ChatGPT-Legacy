import SwiftUI

struct PromptLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (PromptPreset) -> Void
    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private var categories: [String] {
        ["All"] + Array(Set(PromptPreset.builtIn.map(\.category))).sorted()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchField
                categoryStrip
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredPresets) { preset in
                            Button {
                                onSelect(preset)
                            } label: {
                                HStack(alignment: .top, spacing: 13) {
                                    Text(String(preset.category.prefix(1)))
                                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                        .foregroundColor(LegacyTheme.signal)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(LegacyTheme.signalSoft)
                                        )
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(preset.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(LegacyTheme.ink)
                                        Text(preset.prompt)
                                            .font(.caption)
                                            .foregroundColor(LegacyTheme.muted)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(LegacyTheme.signal)
                                        .padding(.top, 4)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(LegacyTheme.paper)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(LegacyTheme.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("prompts.item.\(preset.id)")
                        }
                    }
                    .padding(16)
                }
            }
            .background(LegacyTheme.canvas.ignoresSafeArea())
            .navigationTitle("Prompt library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("prompts.cancel")
                }
            }
        }
        .navigationViewStyle(.stack)
        .accessibilityIdentifier("prompts.screen")
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(LegacyTheme.muted)
            TextField("Find a prompt shape", text: $searchText)
                .accessibilityIdentifier("prompts.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LegacyTheme.faint)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LegacyTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LegacyTheme.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(
                                selectedCategory == category
                                    ? LegacyTheme.userText
                                    : LegacyTheme.muted
                            )
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(
                                Capsule().fill(
                                    selectedCategory == category
                                        ? LegacyTheme.userBubble
                                        : LegacyTheme.paper
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedCategory == category
                                        ? Color.clear
                                        : LegacyTheme.hairline,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("prompts.category.\(category)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var filteredPresets: [PromptPreset] {
        PromptPreset.builtIn.filter { preset in
            let categoryMatches = selectedCategory == "All" || preset.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textMatches = query.isEmpty ||
                preset.title.localizedCaseInsensitiveContains(query) ||
                preset.prompt.localizedCaseInsensitiveContains(query)
            return categoryMatches && textMatches
        }
    }
}
