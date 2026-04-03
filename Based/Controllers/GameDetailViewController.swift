import UIKit

class GameDetailViewController: UIViewController, ScorecardViewDelegate, GameUpdateDelegate {
    
    // UI Components
    private let teamSegmentedControl = UISegmentedControl(items: ["Away", "Home"])
    private let gameHeaderView = GameHeaderView()
    
    // Sticky Header Container
    private let stickyHeaderContainer = UIView()
    private let topLeftLabel: UILabel = {
        let label = UILabel()
        label.text = "BATTER"
        label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        label.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        label.textAlignment = .center
        label.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
        return label
    }()
    private let horizontalScrollView = UIScrollView()
    private let rightHeaderStack = UIStackView()
    
    // Content Scroll View
    private let mainScrollView = UIScrollView()
    private let mainStackView = UIStackView()
    private let scorecardView = ScorecardView()
    private let pitcherLabel = UILabel()
    
    private let currentStateView = CurrentStateView()
    
    // Advisory Banner
    private let advisoryBanner = UIView()
    private let advisoryLabel = UILabel()
    private let advisoryCloseBtn = UIButton(type: .system)
    
    // Data
    private var currentGames: [ScheduleGame] = []
    private var currentLinescore: Linescore?
    private var currentScorecard: ScorecardData?
    private let gamePk: Int

    private var teamSegmentedTopConstraint: NSLayoutConstraint?
    private var dismissedAdvisories: Set<String> = []

    // Constants
    private let nameWidth: CGFloat = 90
    private let inningWidth: CGFloat = 60
    private let headerHeight: CGFloat = 32

    init(gamePk: Int, games: [ScheduleGame]) {
        self.gamePk = gamePk
        self.currentGames = games
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        
        GameService.shared.delegate = self
        GameService.shared.startPolling(gamePk: gamePk)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        GameService.shared.stopPolling()
    }
    
    private func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        
        let font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        
        let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: self, action: #selector(backTapped))
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor], for: .normal)
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor.withAlphaComponent(0.5)], for: .highlighted)
        navigationItem.leftBarButtonItem = backItem
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        appearance.shadowColor = .clear
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - GameUpdateDelegate
    
    func didUpdateLinescore(_ linescore: Linescore, pitches: [PitchEvent]) {
        updateUI(with: linescore, pitches: pitches)
    }
    
    func didUpdateScorecard(_ scorecard: ScorecardData) {
        updateScorecard(with: scorecard)
    }
    
    func didUpdateGameStatus(_ status: String) {
        // Option to show status in UI
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        
        advisoryBanner.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0) // Slight red tint
        advisoryBanner.layer.cornerRadius = 8
        advisoryBanner.layer.borderWidth = 1.0
        advisoryBanner.layer.borderColor = UIColor.red.withAlphaComponent(0.3).cgColor
        advisoryBanner.isHidden = true
        advisoryBanner.translatesAutoresizingMaskIntoConstraints = false
        
        advisoryLabel.font = UIFont(name: "PatrickHand-Regular", size: 14)
        advisoryLabel.textColor = .red
        advisoryLabel.numberOfLines = 0
        advisoryLabel.translatesAutoresizingMaskIntoConstraints = false
        advisoryBanner.addSubview(advisoryLabel)
        
        advisoryCloseBtn.setTitle("✕", for: .normal)
        advisoryCloseBtn.tintColor = .red
        advisoryCloseBtn.addTarget(self, action: #selector(closeAdvisory), for: .touchUpInside)
        advisoryCloseBtn.translatesAutoresizingMaskIntoConstraints = false
        advisoryBanner.addSubview(advisoryCloseBtn)
        
        [teamSegmentedControl, gameHeaderView, stickyHeaderContainer, mainScrollView, currentStateView, advisoryBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Sticky Header Setup
        stickyHeaderContainer.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        
        [topLeftLabel, horizontalScrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            stickyHeaderContainer.addSubview($0)
        }
        
        horizontalScrollView.addSubview(rightHeaderStack)
        rightHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        rightHeaderStack.axis = .horizontal
        rightHeaderStack.distribution = .fillEqually
        horizontalScrollView.showsHorizontalScrollIndicator = false
        horizontalScrollView.delegate = self
        
        // Main Scroll Setup
        mainScrollView.addSubview(mainStackView)
        mainScrollView.delegate = self
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        mainStackView.spacing = 16 
        
        [scorecardView, pitcherLabel].forEach {
            mainStackView.addArrangedSubview($0)
        }
        
        scorecardView.setHeadersVisible(false)
        scorecardView.delegate = self
        
        // Bidirectional sync for horizontal scrolling
        scorecardView.horizontalScrollCallback = { [weak self] offset in
            if self?.horizontalScrollView.contentOffset.x != offset {
                self?.horizontalScrollView.contentOffset.x = offset
            }
        }
        
        pitcherLabel.numberOfLines = 0
        
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        let font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        
        teamSegmentedControl.selectedSegmentIndex = 0
        teamSegmentedControl.addTarget(self, action: #selector(teamChanged), for: .valueChanged)
        
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: pencilColor.withAlphaComponent(0.6)]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: pencilColor]
        teamSegmentedControl.setTitleTextAttributes(normalAttrs, for: .normal)
        teamSegmentedControl.setTitleTextAttributes(selectedAttrs, for: .selected)
        
        NSLayoutConstraint.activate([
            advisoryBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            advisoryBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            advisoryBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            advisoryLabel.topAnchor.constraint(equalTo: advisoryBanner.topAnchor, constant: 8),
            advisoryLabel.leadingAnchor.constraint(equalTo: advisoryBanner.leadingAnchor, constant: 12),
            advisoryLabel.trailingAnchor.constraint(equalTo: advisoryCloseBtn.leadingAnchor, constant: -8),
            advisoryLabel.bottomAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: -8),
            
            advisoryCloseBtn.centerYAnchor.constraint(equalTo: advisoryBanner.centerYAnchor),
            advisoryCloseBtn.trailingAnchor.constraint(equalTo: advisoryBanner.trailingAnchor, constant: -8),
            advisoryCloseBtn.widthAnchor.constraint(equalToConstant: 30),
        ])
        
        teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            teamSegmentedTopConstraint!,
            teamSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            teamSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            teamSegmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            gameHeaderView.topAnchor.constraint(equalTo: teamSegmentedControl.bottomAnchor, constant: 8),
            gameHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Sticky Container
            stickyHeaderContainer.topAnchor.constraint(equalTo: gameHeaderView.bottomAnchor, constant: 8),
            stickyHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stickyHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stickyHeaderContainer.heightAnchor.constraint(equalToConstant: headerHeight),
            
            topLeftLabel.leadingAnchor.constraint(equalTo: stickyHeaderContainer.leadingAnchor),
            topLeftLabel.topAnchor.constraint(equalTo: stickyHeaderContainer.topAnchor),
            topLeftLabel.widthAnchor.constraint(equalToConstant: nameWidth),
            topLeftLabel.bottomAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            
            horizontalScrollView.leadingAnchor.constraint(equalTo: topLeftLabel.trailingAnchor),
            horizontalScrollView.topAnchor.constraint(equalTo: stickyHeaderContainer.topAnchor),
            horizontalScrollView.trailingAnchor.constraint(equalTo: stickyHeaderContainer.trailingAnchor),
            horizontalScrollView.bottomAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            
            rightHeaderStack.topAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.topAnchor),
            rightHeaderStack.leadingAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.leadingAnchor),
            rightHeaderStack.trailingAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.trailingAnchor),
            rightHeaderStack.bottomAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.bottomAnchor),
            rightHeaderStack.heightAnchor.constraint(equalTo: horizontalScrollView.frameLayoutGuide.heightAnchor),

            // Main Scroll
            mainScrollView.topAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor),
            mainStackView.widthAnchor.constraint(equalTo: mainScrollView.frameLayoutGuide.widthAnchor, constant: -32),
            
            pitcherLabel.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            pitcherLabel.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),
            
            currentStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            currentStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            currentStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            currentStateView.heightAnchor.constraint(equalToConstant: 170)
        ])
    }

    private func updateStickyHeaders(inningCount: Int) {
        rightHeaderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        for i in 1...inningCount {
            let label = UILabel()
            label.text = "\(i)"
            label.textAlignment = .center
            label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
            label.textColor = pencilColor
            label.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
            label.layer.borderWidth = 0.5
            label.layer.borderColor = UIColor(white: 0.6, alpha: 0.5).cgColor
            label.widthAnchor.constraint(equalToConstant: inningWidth).isActive = true
            rightHeaderStack.addArrangedSubview(label)
        }
    }

    private func updateUI(with linescore: Linescore, pitches: [PitchEvent]) {
        self.currentLinescore = linescore
        let game = currentGames.first(where: { $0.gamePk == gamePk })
        let awayName = game?.teams.away.team.name ?? "Away"
        let homeName = game?.teams.home.team.name ?? "Home"
        
        gameHeaderView.configure(with: linescore, awayNameOverride: awayName, homeNameOverride: homeName)
        currentStateView.configure(with: linescore, pitches: pitches)
        
        let state = linescore.inningState?.lowercased() ?? ""
        var isLive = state.contains("in progress") || state.contains("live")
        if let game = currentGames.first(where: { $0.gamePk == gamePk }) {
            let detailedState = game.status.detailedState.lowercased()
            if detailedState.contains("final") || detailedState.contains("completed") { isLive = false }
            else if detailedState.contains("scheduled") || detailedState.contains("pre-game") { isLive = false }
            else if detailedState.contains("in progress") { isLive = true }
        }
        currentStateView.isHidden = !isLive
        mainScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: isLive ? 180 : 40, right: 0)
    }

    private func updateScorecard(with scorecard: ScorecardData) {
        let isFirstLoad = self.currentScorecard == nil
        self.currentScorecard = scorecard
        
        // Update Segmented Control Titles with prominent at-bat indicator
        let awayName = scorecard.teams.away.name ?? "Away"
        let homeName = scorecard.teams.home.name ?? "Home"
        
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        let font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let boldFont = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        
        let isTop = scorecard.isTopInning ?? true
        
        // Away (Index 0)
        let awayAttrTitle = NSMutableAttributedString(string: isTop ? "● \(awayName.uppercased())" : awayName.uppercased())
        awayAttrTitle.addAttributes([.font: isTop ? boldFont : font, .foregroundColor: isTop ? pencilColor : pencilColor.withAlphaComponent(0.6)], range: NSRange(location: 0, length: awayAttrTitle.length))
        
        // Home (Index 1)
        let homeAttrTitle = NSMutableAttributedString(string: !isTop ? "● \(homeName.uppercased())" : homeName.uppercased())
        homeAttrTitle.addAttributes([.font: !isTop ? boldFont : font, .foregroundColor: !isTop ? pencilColor : pencilColor.withAlphaComponent(0.6)], range: NSRange(location: 0, length: homeAttrTitle.length))
        
        // Use standard titles since UISegmentedControl attributedTitle support can be finicky with custom fonts across iOS versions
        teamSegmentedControl.setTitle(isTop ? "● \(awayName.uppercased())" : awayName.uppercased(), forSegmentAt: 0)
        teamSegmentedControl.setTitle(!isTop ? "● \(homeName.uppercased())" : homeName.uppercased(), forSegmentAt: 1)
        
        // Default to the team at bat on first load
        if isFirstLoad {
            teamSegmentedControl.selectedSegmentIndex = isTop ? 0 : 1
            scorecardView.setTeam(isHome: !isTop)
        }
        
        scorecardView.configure(with: scorecard)
        let inningCount = max(scorecard.innings.count, 9)
        updateStickyHeaders(inningCount: inningCount)
        updatePitcherList()
        
        if isFirstLoad {
            scrollToActiveCell(scorecard: scorecard)
        }
        
        // Update advisory banner... (rest of method)
        
        // Update advisory banner
        if let advisory = scorecard.advisories.first, !dismissedAdvisories.contains(advisory) {
            advisoryLabel.text = advisory
            advisoryBanner.isHidden = false
            teamSegmentedTopConstraint?.isActive = false
            teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: 8)
            teamSegmentedTopConstraint?.isActive = true
        } else {
            advisoryBanner.isHidden = true
            teamSegmentedTopConstraint?.isActive = false
            teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            teamSegmentedTopConstraint?.isActive = true
        }
    }
    
    @objc private func closeAdvisory() {
        if let current = advisoryLabel.text {
            dismissedAdvisories.insert(current)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.advisoryBanner.isHidden = true
            self.teamSegmentedTopConstraint?.isActive = false
            self.teamSegmentedTopConstraint = self.teamSegmentedControl.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8)
            self.teamSegmentedTopConstraint?.isActive = true
            self.view.layoutIfNeeded()
        }
    }

    @objc private func teamChanged() {
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        scorecardView.setTeam(isHome: isHome)
        updatePitcherList()
    }

    private func updatePitcherList() {
        guard let scorecard = currentScorecard else { return }
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        let pitchers = isHome ? scorecard.pitchers.home : scorecard.pitchers.away
        let pitcherStrings = pitchers.map { "\($0.fullName): \($0.stats)" }
        
        let attributedText = NSMutableAttributedString(string: "PITCHERS\n", attributes: [
            .font: UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        ])
        attributedText.append(NSAttributedString(string: pitcherStrings.joined(separator: "\n") + "\n", attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.7)
        ]))
        
        pitcherLabel.attributedText = pitcherStrings.isEmpty ? nil : attributedText
    }

    // MARK: - ScorecardViewDelegate
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String) {
        let actualPitcher = currentLinescore?.defense?.pitcher?.fullName ?? pitcherName
        let vc = AtBatDetailViewController(event: event, batterName: batter.fullName, pitcherName: actualPitcher)
        if let sheet = vc.sheetPresentationController { sheet.detents = [.medium(), .large()] }
        present(vc, animated: true)
    }

    func didSelectPlayer(_ batter: ScorecardBatter) {
        let vc = PlayerDetailViewController(batter: batter, gameStats: calculatePlayerStats(for: batter))
        if let sheet = vc.sheetPresentationController { sheet.detents = [.medium()] }
        present(vc, animated: true)
    }

    private func scrollToActiveCell(scorecard: ScorecardData) {
        guard let inningNum = scorecard.currentInning,
              let batterId = scorecard.currentBatterId,
              let isTop = scorecard.isTopInning else { return }
        
        let isHomeTeamAtBat = !isTop
        let isViewingTeamAtBat = (teamSegmentedControl.selectedSegmentIndex == 1 && isHomeTeamAtBat) ||
                                (teamSegmentedControl.selectedSegmentIndex == 0 && !isHomeTeamAtBat)
        
        if isViewingTeamAtBat {
            let lineup = isHomeTeamAtBat ? scorecard.lineups.home : scorecard.lineups.away
            guard let rowIndex = lineup.firstIndex(where: { $0.id == batterId }) else { return }
            
            let colIndex = inningNum - 1
            let cellWidth: CGFloat = 60
            let rowHeight: CGFloat = 70
            
            // Wait for layout to settle, then scroll
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                
                // 1. Horizontal Scroll
                let hOffset = max(0, CGFloat(colIndex) * cellWidth - (view.bounds.width / 2) + (cellWidth / 2))
                scorecardView.syncHorizontalOffset(hOffset)
                
                // 2. Vertical Scroll
                let rowY = CGFloat(rowIndex) * rowHeight
                let scorecardY = scorecardView.frame.origin.y
                let targetY = max(0, scorecardY + rowY - (mainScrollView.bounds.height / 3))
                let maxVOffset = max(0, mainScrollView.contentSize.height - mainScrollView.bounds.height)
                
                mainScrollView.setContentOffset(CGPoint(x: 0, y: min(targetY, maxVOffset)), animated: true)
            }
        }
    }

    private func calculatePlayerStats(for batter: ScorecardBatter) -> PlayerGameStats {
        guard let scorecard = currentScorecard else { return PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0) }
        var atBats = 0, hits = 0, runs = 0, rbi = 0, walks = 0, strikeouts = 0
        for inning in scorecard.innings {
            let isHome = teamSegmentedControl.selectedSegmentIndex == 1
            let events = isHome ? inning.home : inning.away
            for event in events where event.batterId == batter.id {
                let result = event.result
                if result == "BB" || result == "IBB" || result == "HBP" { walks += 1 }
                else if result == "SF" || result == "SAC" {}
                else {
                    atBats += 1
                    if ["1B", "2B", "3B", "HR"].contains(result) { hits += 1 }
                }
                if result == "HR" { runs += 1 }
                rbi += event.rbi
                if result == "K" || result == "Ʞ" { strikeouts += 1 }
            }
        }
        return PlayerGameStats(atBats: atBats, hits: hits, runs: runs, rbi: rbi, walks: walks, strikeouts: strikeouts)
    }
}

extension GameDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == horizontalScrollView {
            // Header scroll -> Card scroll
            scorecardView.syncHorizontalOffset(scrollView.contentOffset.x)
        }
    }
}
