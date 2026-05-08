import UIKit

class ScorecardExportCoordinator {
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func shareImage(scorecard: ScorecardData, linescore: Linescore?) {
        guard let viewController = viewController else { return }
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = viewController.view.center
        activityIndicator.hidesWhenStopped = true
        viewController.view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        viewController.view.isUserInteractionEnabled = false
        
        Task {
            let generator = ScorecardImageGenerator()
            let image = await generator.generate(scorecard: scorecard, linescore: linescore)
            
            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                viewController.view.isUserInteractionEnabled = true
                
                let awayName = scorecard.teams.away.name ?? "Away"
                let homeName = scorecard.teams.home.name ?? "Home"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.png")
                try? image.pngData()?.write(to: tempURL)
                
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = viewController.navigationItem.rightBarButtonItem
                }
                viewController.present(activityVC, animated: true)
            }
        }
    }
    
    func sharePDF(scorecard: ScorecardData, linescore: Linescore?) {
        guard let viewController = viewController else { return }
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = viewController.view.center
        activityIndicator.hidesWhenStopped = true
        viewController.view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        viewController.view.isUserInteractionEnabled = false
        
        Task {
            let generator = ScorecardImageGenerator()
            let pdfData = await generator.generatePDF(scorecard: scorecard, linescore: linescore)
            
            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                viewController.view.isUserInteractionEnabled = true
                
                let awayName = scorecard.teams.away.name ?? "Away"
                let homeName = scorecard.teams.home.name ?? "Home"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.pdf")
                try? pdfData.write(to: tempURL)
                
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = viewController.navigationItem.rightBarButtonItem
                }
                viewController.present(activityVC, animated: true)
            }
        }
    }
    
    func showExportCustomizer(scorecard: ScorecardData, linescore: Linescore?) {
        guard let viewController = viewController else { return }
        let exportVC = ScorecardExportViewController(scorecard: scorecard, linescore: linescore)
        let nav = UINavigationController(rootViewController: exportVC)
        viewController.present(nav, animated: true)
    }
}
