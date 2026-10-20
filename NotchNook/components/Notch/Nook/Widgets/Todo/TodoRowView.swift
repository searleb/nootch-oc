//
//  TodoRowView.swift
//  NotchNook
//

import SwiftUI

struct TodoRowView: View {
    var item: TodoTask
    var onToggleCompleted: () -> Void
    var onTogglePriority: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    onToggleCompleted()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary.opacity(0.6))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            // Title
            Text(item.title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(item.isCompleted ? Color.secondary.opacity(0.55) : Color.primary)
                .strikethrough(item.isCompleted, color: .secondary.opacity(0.4))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Priority star
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                    onTogglePriority()
                }
            } label: {
                Image(systemName: item.isPriority ? "star.fill" : "star")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.isPriority ? Color.yellow.opacity(0.9) : Color.secondary.opacity(0.35))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
