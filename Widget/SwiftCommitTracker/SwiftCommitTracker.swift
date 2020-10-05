//
//  SwiftCommitTracker.swift
//  SwiftCommitTracker
//
//  Created by Борис Малашенко on 03.10.2020.
//

import WidgetKit
import SwiftUI

@main
struct CommitCheckerWidget: Widget {
    private let kind: String = "CommitCheckerWidget"

    public var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: LastCommitIntent.self, provider: CommitTimeline()) { entry in
            RepoBranchCheckerEntryView(entry: entry)
        }
        .configurationDisplayName("A Repo's Latest Commit")
        .description("Shows the last commit at the a repo/branch combination.")
    }
}
struct Commit {
    let message: String
    let author: String
    let date: String
}

struct LastCommitEntry: TimelineEntry {
    public let date: Date
    public let commit: Commit
}

struct CommitLoader {
    static func fetch(account: String, repo: String, branch: String, completion: @escaping (Result<Commit, Error>) -> Void) {
        let branchContentsURL = URL(string: "https://api.github.com/repos/\(account)/\(repo)/branches/\(branch)")!
        let task = URLSession.shared.dataTask(with: branchContentsURL) { (data, response, error) in
                    guard error == nil else {
                        completion(.failure(error!))
                        return
                    }
                    let commit = getCommitInfo(fromData: data!)
                    completion(.success(commit))
            }
        task.resume()
    }

    static func getCommitInfo(fromData data: Foundation.Data) -> Commit {
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        let commitParentJson = json["commit"] as! [String: Any]
        let commitJson = commitParentJson["commit"] as! [String: Any]
        let authorJson = commitJson["author"] as! [String: Any]
        let message = commitJson["message"] as! String
        let author = authorJson["name"] as! String
        let date = authorJson["date"] as! String
        return Commit(message: message, author: author, date: date)
    }
}

struct CommitTimeline: IntentTimelineProvider {
    func placeholder(in context: Context) -> LastCommit {
        let fakeCommit = Commit(message: "message", author: "author", date: "date")
        let branch = RepoBranch(account: "account", repo: "repo", branch: "branch")
        return LastCommit(date: Date(), commit: fakeCommit, branch: branch)
    }
    
    public func getSnapshot(for configuration: LastCommitIntent, in context: Context, completion: @escaping (LastCommit) -> ()) {
        let fakeCommit = Commit(message: "Fixed stuff", author: "John Appleseed", date: "2020-06-23")
        let entry = LastCommit(
            date: Date(),
            commit: fakeCommit,
            branch: RepoBranch(
                account: "apple",
                repo: "swift",
                branch: "master"
            )
        )
        completion(entry)
    }

    public func getTimeline(for configuration: LastCommitIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!

        guard let account = configuration.account,
              let repo = configuration.repo,
              let branch = configuration.branch
        else {
            let commit = Commit(message: "Failed to load commits", author: "", date: "")
            let entry = LastCommit(date: currentDate, commit: commit, branch: RepoBranch(
                account: "???",
                repo: "???",
                branch: "???"
            ))
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
            return
        }
        
        CommitLoader.fetch(account: account, repo: repo, branch: branch) { result in
                    let commit: Commit
                    if case .success(let fetchedCommit) = result {
                        commit = fetchedCommit
                    } else {
                        commit = Commit(message: "Failed to load commits", author: "", date: "")
                    }
                    let entry = LastCommit(date: currentDate, commit: commit, branch: RepoBranch(
                        account: account,
                        repo: repo,
                        branch: branch
                    ))
                    let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
                    completion(timeline)
                }
    }
    
    typealias Entry = LastCommit
    typealias Intent = LastCommitIntent
    
}

struct RepoBranch {
    let account: String
    let repo: String
    let branch: String
}

struct LastCommit: TimelineEntry {
    public let date: Date
    public let commit: Commit
    public let branch: RepoBranch

    var relevance: TimelineEntryRelevance? {
        return TimelineEntryRelevance(score: 10) // 0 - not important | 100 - very important
    }
}

struct RepoBranchCheckerEntryView : View {
    var entry: CommitTimeline.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.branch.account)/\(entry.branch.repo)'s \(entry.branch.branch) Latest Commit")
                .font(.system(.title3))
                .foregroundColor(.black)
            Text("\(entry.commit.message)")
                .font(.system(.callout))
                .foregroundColor(.black)
                .bold()
            Text("by \(entry.commit.author) at \(entry.commit.date)")
                .font(.system(.caption))
                .foregroundColor(.black)
            Text("Updated at \(Self.format(date:entry.date))")
                .font(.system(.caption2))
                .foregroundColor(.black)
        }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [.orange, .yellow]), startPoint: .top, endPoint: .bottom))
    }

    static func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy HH:mm"
        return formatter.string(from: date)
    }
}

