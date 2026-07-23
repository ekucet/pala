//
//  ConsolePanelView.swift
//  Pala
//
//  Floating, draggable console panel: level filter, search, clear, share.
//

#if canImport(UIKit)
import UIKit

@MainActor
final class ConsolePanelView: UIView, UITableViewDataSource, UITableViewDelegate {

    var onClose: (() -> Void)?
    var onShare: ((String) -> Void)?

    private let header = UIView()
    private let titleLabel = UILabel()
    private let table = UITableView(frame: .zero, style: .plain)
    private let search = UISearchBar()
    private let filter = UISegmentedControl(items: ["All", "Info", "Warn", "Error"])

    private var filtered: [PalaLog] = []
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = UIColor(white: 0.08, alpha: 0.97)
        layer.cornerRadius = 14
        clipsToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor

        // Header (drag handle)
        header.backgroundColor = UIColor(white: 0.14, alpha: 1)
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        header.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))

        titleLabel.text = "Console"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let clear = headerButton("Clear", #selector(clearTapped))
        let share = headerButton("Share", #selector(shareTapped))
        let close = headerButton("✕", #selector(closeTapped))
        let stack = UIStackView(arrangedSubviews: [clear, share, close])
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)

        filter.selectedSegmentIndex = 0
        filter.selectedSegmentTintColor = .systemBlue
        filter.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        filter.addTarget(self, action: #selector(refilter), for: .valueChanged)
        filter.translatesAutoresizingMaskIntoConstraints = false
        addSubview(filter)

        search.searchBarStyle = .minimal
        search.placeholder = "Search"
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        if let tf = search.value(forKey: "searchField") as? UITextField {
            tf.textColor = .white
            tf.backgroundColor = UIColor(white: 1, alpha: 0.08)
        }
        addSubview(search)

        table.backgroundColor = .clear
        table.separatorColor = UIColor(white: 1, alpha: 0.08)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 48
        table.register(LogCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        addSubview(table)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            filter.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            filter.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            filter.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            search.topAnchor.constraint(equalTo: filter.bottomAnchor, constant: 4),
            search.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            search.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            table.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 2),
            table.leadingAnchor.constraint(equalTo: leadingAnchor),
            table.trailingAnchor.constraint(equalTo: trailingAnchor),
            table.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        PalaConsole.shared.onChange = { [weak self] in self?.reload() }
        reload()
    }

    private func headerButton(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.tintColor = .white
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    // MARK: - Data

    func reload() {
        let all = PalaConsole.shared.logs
        let minLevel: PalaLogLevel?
        switch filter.selectedSegmentIndex {
        case 1: minLevel = .info
        case 2: minLevel = .warning
        case 3: minLevel = .error
        default: minLevel = nil
        }
        let query = (search.text ?? "").lowercased()
        filtered = all.filter { log in
            (minLevel == nil || log.level.rawValue >= minLevel!.rawValue) &&
            (query.isEmpty || log.message.lowercased().contains(query)
                || log.category.lowercased().contains(query))
        }
        table.reloadData()
        if !filtered.isEmpty {
            table.scrollToRow(at: IndexPath(row: filtered.count - 1, section: 0), at: .bottom, animated: false)
        }
    }

    @objc private func refilter() { reload() }
    @objc private func clearTapped() { PalaConsole.shared.clear() }
    @objc private func shareTapped() { onShare?(PalaConsole.shared.exportText()) }
    @objc private func closeTapped() { onClose?() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! LogCell
        let log = filtered[indexPath.row]
        cell.configure(time: timeFormatter.string(from: log.date), log: log)
        return cell
    }

    // MARK: - Drag

    @objc private func drag(_ g: UIPanGestureRecognizer) {
        guard let sv = superview else { return }
        let t = g.translation(in: sv)
        center = CGPoint(x: center.x + t.x, y: center.y + t.y)
        g.setTranslation(.zero, in: sv)
    }
}

extension ConsolePanelView: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { reload() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

@MainActor
private final class LogCell: UITableViewCell {
    private let badge = PaddedLabel()
    private let cat = UILabel()
    private let msg = UILabel()
    private let time = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        badge.inset = UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5)
        badge.font = .systemFont(ofSize: 9, weight: .heavy)
        badge.textColor = .white
        badge.layer.cornerRadius = 3
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        cat.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        cat.textColor = .systemTeal
        cat.setContentHuggingPriority(.required, for: .horizontal)

        time.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        time.textColor = UIColor(white: 1, alpha: 0.4)

        msg.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        msg.textColor = .white
        msg.numberOfLines = 0

        let top = UIStackView(arrangedSubviews: [badge, cat, time, UIView()])
        top.spacing = 6
        top.alignment = .center
        let v = UIStackView(arrangedSubviews: [top, msg])
        v.axis = .vertical
        v.spacing = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            v.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(time t: String, log: PalaLog) {
        badge.text = log.level.name
        badge.backgroundColor = log.level.color
        cat.text = log.category
        time.text = t
        msg.text = log.message
    }
}
#endif
