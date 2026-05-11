import SwiftUI

struct SingleQuestionView: View {
    let question: Question

    var body: some View {
        Text(question.text)
            .font(.subheadline)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .multilineTextAlignment(.leading)
    }
}

struct GroupedQuestionView: View {
    let question: Question

    var body: some View {
        Text(question.text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

struct QuestionGroupView: View {
    let group: QuestionGroup

    var body: some View {
        VStack(alignment: .leading) {
            if let title = group.title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.questions) { item in
                        GroupedQuestionView(question: item.value)
                            .aspectRatio(1, contentMode: .fill)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
        }
    }
}
