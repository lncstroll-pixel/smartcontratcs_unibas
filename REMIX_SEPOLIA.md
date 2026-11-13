# Schritt-für-Schritt: Remix und vorbereitetes Sepolia-Beispiel

Stand: 12. November 2026. Der Code wurde ausschließlich lokal mit simuliertem ETH
geprüft. Diese Anleitung bereitet eine spätere manuelle Sepolia-Demo vor;
ein Sepolia-Deployment und ein Zugriff auf persönliche Wallets wurden nicht
durchgeführt. Die mitgelieferten Skripte verwenden ausschließlich Hardhat intern.

## 1. Dateien auswählen

Für einen übersichtlichen Remix-Workspace die zwei Dateien aus `remix/` übernehmen:

```text
EquityToken.sol
CrowdfundingProject.sol
```

Beide liegen im selben Remix-Ordner. Diese Kopien enthalten die explizit auf
OpenZeppelin **4.9.6** festgelegten Imports:

```solidity
// EquityToken.sol
import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Votes.sol";

// CrowdfundingProject.sol
import "./EquityToken.sol";
import "@openzeppelin/contracts@4.9.6/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.6/utils/math/Math.sol";
```

`ERC20Permit` wird von `ERC20Votes` bereits importiert und geerbt. Kein zusätzlicher
Permit-Import oder eigener Permit-Contract ist nötig. Die editierbaren lokalen
Originale bleiben unter `contracts/`; deren npm-Imports beziehen ihre feste Version
aus Paket- und Lockdatei. Remix unterstützt die Versionsangabe im npm-Import und
alternativ eine GitHub-URL mit festem Release-Tag, siehe
[offizielle Importanleitung](https://remix-ide.readthedocs.io/en/latest/import.html).

**Falls der Importdownload fehlschlägt:** In einem eigenen, leeren Workspace nur
`reports/CrowdfundingProject.remix.sol` laden. Diese generierte Ersatzdatei enthält
beide eigenen Contracts sowie die benötigten Bibliotheksquellen. Sie wird lokal
mit demselben Compiler erneut geprüft und benötigt keine externen Imports.
Nicht parallel beide Varianten im selben Arbeitsablauf bearbeiten.

Ein weiterer möglicher Importweg ist zum Beispiel
`https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/extensions/ERC20Votes.sol`.
Er benötigt weiterhin Internetzugriff. `master`, `main`, `latest` oder beliebige
5.x-Beispiele vermeiden. Bibliotheks-Pragmas und Bibliotheksquellen nicht ändern.

## 2. Compiler einstellen

In [Remix](https://remix.ethereum.org/) das Modul **Solidity Compiler** öffnen:

| Einstellung | Wert |
|---|---|
| Compiler | **0.8.9**, stabiler Build `0.8.9+commit.e5eed63a` |
| Eigene Pragmas | `pragma solidity 0.8.9;` |
| Optimizer | aktiviert, **200** Runs |
| EVM-Ziel | **london** |
| Pipeline | klassische Codegenerierung; **viaIR ausgeschaltet**, falls angezeigt |
| Zu kompilierende Datei | `CrowdfundingProject.sol` beziehungsweise die Ersatzdatei |

Der Compiler wird im Dropdown ausgewählt; die Quelldatei stellt nur sicher, dass
eine falsche Version zurückgewiesen wird. Näheres zu den Bedienelementen:
[Remix-Compiler](https://remix-ide.readthedocs.io/en/latest/compile.html).
Keine 0.8.24-/0.8.38-Auswahl als Reparatur verwenden. Die Versionen und verbleibenden
Compilergrenzen sind in `DEPENDENCY_NOTES.md` und `BUILD_INFO.md` erklärt.

## 3. Rollen und kleine Demo-Werte

Zunächst **Deploy & Run → Environment → Remix VM** wählen, zum Beispiel die
Shanghai-Variante ohne Live-Chain-Fork. Die VM stellt Testkonten mit simuliertem
ETH bereit. Die UI nennt eine spätere Browser-Wallet-Verbindung je nach Version
**Browser Extension** oder **Injected Provider**; die VM benötigt keine solche
Verbindung. Siehe [Remix-Umgebungen](https://remix-ide.readthedocs.io/en/latest/run.html).

Für den ganzen Ablauf drei getrennte Konten verwenden:

| Konto | Rolle | Anfangsbestand / Kauf |
|---|---|---|
| A | feste Unternehmensadresse, kann zugleich deployen | erhält 2.000 ROB |
| B | Investorin Alice | kauft 2.000 ROB für 0,002 ETH |
| C | Investor Bob | kauft 1.000 ROB für 0,001 ETH |

Alle Mengen sind ganze Token: `decimals() = 0`. Preis: **1.000.000.000.000 Wei**
pro Token = **0,000001 ETH**. Gesamtangebot: 10.000 ROB; Unternehmen: 2.000;
Projektreserve: 8.000. Im einzigen Verkauf angeboten: 5.000; Mindestabsatz: 3.000.
Ein Verkauf von 3.000 Token sammelt daher **0,003 ETH**.

Die Frist von **600 Sekunden** startet mit dem Deployment. Die drei Konten und
Zahlbeträge vorher bereitlegen. Für eine langsamere Vorführung alternativ
`duration = 1200` wählen; das ist ein Konstruktorwert und lässt sich nachher nicht
mehr ändern. 600 Sekunden erlauben den Kaufablauf und vermeiden die bisherige
Tagesfrist. Das Abstimmungsfenster bleibt bei **50 Blöcken**.

## 4. Crowdfunding deployen und Tokeninstanz laden

Im Contract-Dropdown **CrowdfundingProject** auswählen. **VALUE = 0 Wei**.
Die Konstruktorfelder ausklappen und eingeben:

```text
_company:            Adresse von Konto A
_totalSupply:        10000
_companyAllocation:  2000
_terms:              [1000000000000,5000,3000,600]
```

Der letzte Parameter ist ein Tupel in der Reihenfolge Preis, angebotenes Volumen,
Mindestabsatz, Dauer in Sekunden. Falls Remix die Felder einzeln anzeigt, dieselben
Werte einzeln eintragen. Falls das Feld einen anderen lokalen Parameternamen
anzeigt, sind Reihenfolge und Werte maßgeblich.

**Nur CrowdfundingProject manuell deployen.** Dessen Konstruktor erzeugt zuerst
den zugehörigen EquityToken und richtet danach den Verkauf ein. Ein vorher separat
deployter Token würde nicht an dieses Projekt angebunden. Eine weitere Start- oder
Initialisierungstransaktion ist nicht nötig.

Nach dem Deployment am Projekt `token()` lesen. Diese Adresse mit dem kompilierten
ABI **EquityToken** über **At Address / Add Contract** laden. Dabei wird die
vorhandene Instanz geöffnet, kein zweiter Token deployt. Beim Wechsel des
Contract-Dropdowns nicht versehentlich erneut auf Deploy klicken.

Prüfen:

```text
token.totalSupply()                 = 10000
token.balanceOf(A)                  = 2000
token.balanceOf(Projektadresse)     = 8000
token.decimals()                    = 0
project.getSale().terms             = [1000000000000,5000,3000,600]
project.getSale().status            = 0 (Active)
```

## 5. Token kaufen

Während `block.timestamp < getSale().endTime`:

1. Konto B wählen; VALUE auf **2000000000000000 Wei** setzen; `buyTokens(2000)`
   aufrufen. Das sind 0,002 ETH.
2. Konto C wählen; VALUE auf **1000000000000000 Wei** setzen; `buyTokens(1000)`
   aufrufen. Das sind 0,001 ETH.
3. **VALUE auf 0 Wei zurücksetzen.** Alle folgenden Aufrufe sind nicht zahlbar.
4. `getSale()` prüfen: `soldTokens = 3000`; Einnahmen entsprechen
   `3000 × priceWeiPerToken = 3000000000000000 Wei`.

Jede positive ganze Menge ab einem Token ist erlaubt. Menge und Zahlung müssen
exakt zusammenpassen; Unter-/Überzahlung sowie Käufe über den Cap werden vollständig
zurückgewiesen. Ein ausverkauftes Angebot wird trotzdem erst nach Fristende
finalisiert. Die Käufer erhalten zunächst einen Anspruch, noch keine Token.

## 6. Finanzierung abschließen und Token abholen

Bis mindestens `getSale().endTime` warten. Dann von einem beliebigen Konto
`finalizeSale()` aufrufen. Reine Leseaufrufe erzeugen keinen Block. Wenn die VM
nach dem Warten noch einen alten Blockzeitstempel anzeigt, wird spätestens die
nächste Transaktion unter dem aktuellen VM-Zeitstempel geprüft. Bei einer VM mit
manuell gesteuerter Zeit deren Zeit-/Mining-Steuerung verwenden; die lokale
automatische Demo erledigt die Zeitsteuerung deterministisch.

Bei diesem Absatz erreicht der Verkauf den Mindestwert:

```text
getSale().status = 1 (Successful)
initialAmount()  = 1800000000000000 Wei = 0,0018 ETH
governedAmount() = 1200000000000000 Wei = 0,0012 ETH
```

Konto B ruft `claimTokens()` auf; danach Konto C ebenfalls. Nun halten B 2.000
und C 1.000 ROB. Ein Claim ist pro Käufer einmalig und vollständig. Die 5.000
unverkauften Reservetoken verbleiben im Projekt und geben ihm keine ausführbaren
Stimmen; ein Folgeverkauf ist nicht mehr implementiert.

Die erste Tranche kann jetzt durch `withdrawInitialTranche()` ausgelöst werden.
Der Aufrufer darf jedes Konto sein; die 0,0018 ETH gehen ausschließlich an A.
Ein zweiter Aufruf wird zurückgewiesen. Die Reihenfolge zu Claims ist frei.

## 7. Stimmrechte vor dem Proposal aktivieren

Auf **EquityToken**, jeweils mit dem passenden Konto:

```text
Konto B: delegate(Adresse von B)
Konto C: delegate(Adresse von C)
Konto A: delegate(Adresse von A)     // optional; aktiviert die Gründerstimmen
```

Jede Transaktion bestätigen lassen. `getVotes(B) = 2000`, `getVotes(C) = 1000`;
nach Selbstdelegation von A auch `getVotes(A) = 2000`. Die alternative Delegation
an eine andere Adresse ist möglich; dann stimmt diese Adresse mit dem delegierten
historischen Gewicht. Delegation überträgt keine Token.

**Claims und Delegationen vor dem Erstellen des Proposals abschließen.**
ERC20Votes speichert historische Stimmgewichte als Checkpoints. Das Proposal
verwendet den Stand am Ende seines Erstellungsblocks. Spätere Übertragungen ändern
den Tokenbesitz, aber nicht rückwirkend diesen historischen Stand. Das verhindert,
dass derselbe Bestand zuerst bei B und nach einem Transfer nochmals bei C zählt.

## 8. Proposal erstellen

Zur Projektinstanz wechseln, Konto A wählen, VALUE = 0, `createReleaseProposal()`
aufrufen. Nur die feste Unternehmensadresse darf einen Antrag stellen. Es geht
ausschließlich um die noch offene Governance-Tranche; weder Betrag noch Empfänger
sind frei wählbar. Ein weiteres paralleles Proposal ist ausgeschlossen.

`proposalCount()` liefert beim ersten Versuch **1**. `getProposal(1)` zeigt
`snapshotBlock`, `endBlock` und `eligibleBase`. Im Beispiel:

```text
eligibleBase        = 2000 + 3000 = 5000
requiredYesVotes(1)  = floor(5000 / 2) + 1 = 2501
endBlock            = snapshotBlock + 50
```

Nicht abgeholte erfolgreiche Käufe zählen bereits zu dieser Basis. Sie haben vor
Claim und Delegation noch kein nutzbares Investorengewicht. Bei großer Inaktivität
kann dadurch die absolute Mehrheit unerreichbar bleiben. Die Reserve zählt nicht
zur Basis. Der Gründerbestand allein reicht hier mit 2.000 Stimmen nicht; zusätzliche
Käufe oder Delegationen an A können seine Stimmkraft jedoch erhöhen.

## 9. Abstimmen

Ab dem Block **nach** `snapshotBlock` bis einschließlich `endBlock`:

```text
Konto B am Projekt: vote(1, 1)     // Ja mit historischen 2000 Stimmen
Konto C am Projekt: vote(1, 1)     // Ja mit historischen 1000 Stimmen
```

`support = 0` bedeutet Nein; `1` Ja. Andere Werte sind ungültig. Eine Adresse kann
pro Proposal nur einmal abstimmen. Transfers bleiben zulässig; die aktuelle Balance
ist für dieses Proposal unerheblich.

3.000 Ja-Stimmen erfüllen `Ja > 5000 / 2`. Genau 2.500 reichen nicht. Die Regel
ist eine absolute Mehrheit der festgelegten Basis, keine bloße Mehrheit der
abgegebenen Stimmen und kein zusätzliches 25-%-Quorum. Nichtbeteiligung senkt
die benötigte Ja-Zahl nicht. Nein-Stimmen werden protokolliert.

## 10. Auswerten und zweite Tranche freigeben

Warten, bis die aktuelle Blocknummer **größer als `endBlock`** ist. Ein Aufruf,
der erst im Folgeblock aufgenommen wird, ist zulässig; für die Vorführung lieber
eine zusätzliche Blockbestätigung abwarten.

In der Remix VM wachsen Blocknummern gewöhnlich nur mit Transaktionen. Bloßes
Warten oder `getProposal` lesen beendet dort keine 50-Blöcke-Abstimmung. Bei Bedarf
mit VALUE = 0 wiederholt lokale Selbsttransaktionen auslösen und die Blocknummer
prüfen. Für eine automatische schnelle Vorführung ist `pnpm demo` geeigneter:
dort werden die nötigen lokalen Blöcke gezielt erzeugt. Auf einem öffentlichen
Testnetz werden Blöcke unabhängig von euren Transaktionen produziert.

Danach von einem beliebigen Konto:

1. `finalizeProposal(1)` aufrufen; `getProposal(1).approved = true` prüfen.
2. `executeProposal(1)` aufrufen. Die 0,0012 ETH gehen ausschließlich an A.
3. `getProposal(1).executed = true` und `totalETHLiability() = 0` prüfen,
   sofern die Anfangstranche schon ausgezahlt wurde.
4. Zweiter Execute und weitere Vorschläge nach Auszahlung sind gesperrt.

Auswertung und Auszahlung sind bewusst getrennt. Ein abgelehntes Proposal kann
nicht ausgeführt werden; A kann anschließend einen neuen Antrag mit neuem
Snapshot stellen. Nach erfolgreichem, noch unausgeführtem Proposal bleibt dessen
Slot bis zur Ausführung belegt. Wenn A ein Contract ist und ETH zurückweist,
rollt die Auszahlung samt Flags zurück und lässt sich später erneut versuchen.

## 11. Refund und Ablehnung zeigen

Für einen Fehlschlag eine **neue Projektinstanz** mit denselben Parametern deployen,
aber insgesamt nur beispielsweise 1.000 ROB kaufen. Nach Fristende `finalizeSale()`
aufrufen: Status **2 (Failed)**. Jeder Käufer ruft selbst `refund()` auf und erhält
seine exakte Einzahlung zurück. Keine Investorentoken, keine Governance und keine
Tranchenauszahlung; ein zweiter Refund wird zurückgewiesen. Gas wird zusätzlich
vom jeweiligen lokalen Konto getragen.

Für eine abgelehnte Abstimmung eine erfolgreiche neue Instanz verwenden, aber
höchstens 2.500 Ja-Stimmen abgeben oder alle Stimmen auslassen. Nach dem Endblock
finalisieren: `approved = false`; die Governance-Tranche bleibt gebunden. Für
erfolgreiche Verkäufe gibt es weder automatischen Refund noch Admin-Notabzug.

## 12. Spätere manuelle Sepolia-Vorführung

Dieser Abschnitt wird hier **nicht ausgeführt**. Sepolia ist das von Ethereum
empfohlene Anwendungstestnetz; Chain-ID **11155111**. Quellen:
[Ethereum-Netzwerke](https://ethereum.org/developers/docs/networks/) und
[Sepolia-Clientkonfiguration](https://github.com/eth-clients/sepolia/blob/main/README.md).

Für eine spätere eigenständige Vorführung in Remix können dieselben Dateien,
Compilerparameter, Kontorollen und kleinen Kaufbeträge verwendet werden. Der
Benutzer wählt dann selbst eine eigens dafür bestimmte Browser-Testwallet und
Sepolia im Browser-Extension-/Injected-Provider-Modus, kontrolliert vor jeder
Signatur Netzwerk und Empfänger und führt die oben beschriebenen Transaktionen
manuell aus. Seed-Phrases oder Private Keys werden weder in Projektdateien noch
in diese Anleitung eingetragen. Es gibt kein mitgeliefertes Remote-Deployskript.

Alle drei Testkonten benötigen etwas Sepolia-Test-ETH für Gas; A zusätzlich für
das Deployment beider zusammen erzeugter Contracts. Die Kaufbeträge von insgesamt
0,003 ETH enthalten diese Gebühren nicht. Ein bestimmter Gaspreis, Faucet-Zugang
oder eine erfolgreiche Testnetzverbindung wurde hier nicht geprüft.

Für die Abstimmung 50 tatsächliche Blöcke abwarten; bei 12-Sekunden-Slots sind
das ungefähr zehn Minuten, bei ausgelassenen Slots länger. Das ist eine
Zeitabschätzung, keine Contractfrist in Sekunden. Quelle:
[Ethereum: Blockproduktion](https://ethereum.org/developers/docs/consensus-mechanisms/pos/block-proposal).
Die Verkaufsfrist bleibt separat zehn Minuten ab dem Deployment. Für den gesamten
manuellen Ablauf einschließlich Claims, Delegationen und Transaktionsbestätigungen
etwa 25–35 Minuten einplanen.

Die lokale Prüfung bestätigt Solidity-Build und simulierte Abläufe. Die Remix-UI,
Browser-Importdienste und ein öffentliches Sepolia-Deployment sind getrennte,
hier nicht tatsächlich ausgeführte Prüfungen.
