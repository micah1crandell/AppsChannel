import SwiftUI
import AppKit

struct RecentDocumentsSubDeckView: View {
    let app: DiscoveredApp
    let onClose: () -> Void

    @ObservedObject private var service = RecentDocumentsService.shared
    @State private var hoveredDocId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(app.accentColor)

                    Text("\(app.name) • Recent Documents")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if !service.activeRecentDocuments.isEmpty {
                        Text("\(service.activeRecentDocuments.count)")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15), in: Capsule())
                    }
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Content area
            if service.isQuerying {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Indexing recent files via Spotlight...")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if service.activeRecentDocuments.isEmpty {
                let hasDocTypes = RecentDocumentsService.hasDocumentTypes(forAppAt: app.url)
                HStack(spacing: 8) {
                    Image(systemName: hasDocTypes ? "doc.text.magnifyingglass" : "app.dashed")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(hasDocTypes ? "No recent documents found for \(app.name)" : "\(app.name) does not manage document files")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.activeRecentDocuments) { doc in
                            RecentDocumentTile(
                                doc: doc,
                                isHovered: hoveredDocId == doc.id,
                                onOpen: {
                                    openDocument(doc)
                                }
                            )
                            .onHover { isHovered in
                                hoveredDocId = isHovered ? doc.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.12).opacity(0.96), Color(white: 0.06).opacity(0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
        .task(id: app.url) {
            await service.fetchRecentDocuments(for: app)
        }
    }

    private func openDocument(_ doc: RecentDocumentItem) {
        NSWorkspace.shared.open(doc.url)
        SoundEffectsManager.shared.playLaunch()
        onClose()
    }
}

private struct RecentDocumentTile: View {
    let doc: RecentDocumentItem
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(spacing: 6) {
                Image(nsImage: doc.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text(doc.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 82)

                Text(doc.formattedRelativeDate)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(width: 96, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                let path = doc.url.path
                if !NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = ["-R", path]
                    try? task.run()
                }
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(doc.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}
