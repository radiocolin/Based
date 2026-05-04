# Typography & Aesthetic Design Suggestions

To tighten up the app’s aesthetic and move away from the "marker-heavy" look, the design should lean into the concept of **Printed vs. Handwritten** contrast. Real scorecards are high-precision grids of printed lines and labels that become personalized through handwritten notes.

## 1. The Recommended Pairing: Roboto Condensed
For the "printed" typeface, use **Roboto Condensed** (or **IBM Plex Sans Condensed**).
*   **Why it works:** Condensed fonts are the industry standard for baseball programs and scorecards because they allow high data density (fitting 9+ innings and complex stat columns) while maintaining a clean, authoritative look.
*   **Complementing Patrick Hand:** Patrick Hand is casual and whimsical. Roboto Condensed provides a rigid, structural "anchor" that makes the handwriting feel intentional rather than cluttered.

## 2. Proposed Typography Mapping
Scaling back the fonts into specific "functional roles" will professionalize the UI:

| Font | Role | Examples |
| :--- | :--- | :--- |
| **Permanent Marker** | **The Final Ink** | Scoring outcomes in the Scorecard (e.g., "K", "HR", "6-3"), high-level results (e.g., "FINAL"), and Navigation Bar titles. |
| **Patrick Hand** | **The Lead Pencil** | Secondary scoring notes (Balls/Strikes/Outs), pitch counts, at-bat descriptions, and empty-state messages. |
| **Roboto Condensed** | **The Printed Card** | Column headers (W, L, AVG, HR), inning numbers (1–9), Team Names in lists, player names in the lineup, and fixed field labels (e.g., "BATTER:"). |

## 3. Aesthetic "Tightening" Strategies
To make the app read more like a professional scorecard without overusing the Marker font:

*   **Structural Headers:** Use **Roboto Condensed Bold in All-Caps** for section headers (e.g., "NATIONAL LEAGUE EAST" or "HOME LINEUP"). This mimics the pre-printed labels on a physical card.
*   **Monospaced Stats:** For statistical data like ERA, WHIP, or the Box Score totals, use a monospaced variant like **Roboto Mono**. This ensures that numbers align vertically in columns, which is critical for the "printed data" look.
*   **Grid Contrast:** Ensure grid lines (`AppColors.grid`) are very thin and precise. The "magic" of the scorecard aesthetic comes from the contrast between the perfect, rigid geometry of the grid and the organic, slightly "messy" handwriting inside it.
*   **Color Hierarchy:**
    *   Use **Pencil Gray** for Patrick Hand notes.
    *   Use **Team-Specific Colors** (bold) for Permanent Marker outcomes.
    *   Use a **Solid Black or Deep Navy** for the "Printed" structural font (Roboto) to differentiate it from the scorer's marks.
