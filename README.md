# ResidentHub (residenthub_dashboard)

Flutter mobile app for **City Residences Condominium Corporation** - a redesigned,
touch-first version of the ResidentHub web demo. All content (units, bookings, dues,
grievances, announcements, unit status, motor parking, access management...)
comes from the web demo; the interface is new.

## Open in Android Studio
1. Create a project: *File > New > New Flutter Project*, name it `residenthub_dashboard`
   (org e.g. `ph.residenthub`). Or, in this folder, run:
   `flutter create --project-name residenthub_dashboard --org ph.residenthub .`
2. Copy `lib/`, `assets/`, `test/`, `pubspec.yaml` and `analysis_options.yaml` from this
   folder over the generated project (overwrite).
3. `flutter pub get`, pick an emulator or device, press Run.
Requires Flutter 3.22+ (Dart 3.3+). Two packages are used for documents: `file_picker`
(import files, save exports) and `archive` (reads/writes .docx and .xlsx). Run `flutter pub get`
after copying `pubspec.yaml`.

## Sign-in accounts
Every account needs its password (5 wrong tries lock sign-in for a minute).
- Administrator: username `admin` (also `owner`, `joseph`) / password `admin123`
  (change `adminPassword` in `lib/core/app_state.dart` before handing the app over)
- Residents: `maria.santos@cityresidences.ph` or `jessele.fugaban@cityresidences.ph` / `resident123`
Forgot password (residents): enter the registered mobile number, get a 6-digit code, set a new
password. No SMS gateway is connected yet, so the code is shown on screen
(`AppState.showTestCode` in `lib/core/app_state.dart`; set it to `false` and send the SMS from
`startPasswordReset` when you go live).

New accounts are created by the administrator (Manage access); they start with the temporary
password `resident123` and can change it in Settings. The administrator can also reset any
password from Manage access.

Accounts live on the phone only (in memory); real multi-device sign-in needs a backend.

## Project structure (one file per screen)
```
lib/
  main.dart                      app entry, theme + login/role switching
  core/
    app_state.dart               models, sample data, shared AppState
    theme.dart                   pastel palette + Material 3 theme (light/dark)
    doc_model.dart               document model (blocks: headings, text, bullets, tables)
    doc_seed.dart                the documents that ship with the app (edit the wording here)
  services/doc_files.dart        Word/Excel export, Word/Excel/CSV/text import, save dialog
  widgets/                       reusable UI: floating_nav, ring_gauge, line_chart,
                                 pastel cards/tiles, page scaffolds, form_sheet, ...
  screens/
    shared/calendar_screen.dart  month calendar (events, bookings, dues dates) + home card
    shared/document_viewer_screen.dart  opens a document, download as Word / Excel
    auth/login_screen.dart
    resident/
      resident_shell.dart        floating bottom navigation (Home, Book, Dues, More)
      home_screen.dart  book_screen.dart  dues_screen.dart
      more_screen.dart  reservations_screen.dart  grievances_screen.dart
      documents_screen.dart  finance_docs_screen.dart  unit_status_screen.dart  settings_screen.dart
      notifications_sheet.dart   resident_screens.dart (barrel)
    admin/
      admin_shell.dart           floating bottom navigation (Home, Units, Facility, Finance, More)
      home_screen.dart  units_screen.dart  facility_screen.dart  finance_screen.dart
      more_screen.dart  announcements_screen.dart
      grievances_screen.dart  unit_status_screen.dart  documents_screen.dart  finance_docs_screen.dart
      access_screen.dart
      admin_actions.dart         jump targets, attention sheet, search items
      admin_screens.dart (barrel)
```
Each bottom-navigation tab and each "More" page lives in its own file.

## Notes
- Visitor management and vendor management have been removed from this build (both resident and admin sides).
- Everything runs on in-memory sample data and resets when the app restarts.
- Resident and admin share one state: a booking, grievance, unit status update or
  parking request made as a resident shows up for the admin, and decisions flow back.
- The earnings line chart, "Recent activity", "Upcoming facility bookings" and the resident notifications are built from what is recorded in the app (payments, bookings, grievances, announcements). They start empty or with the seed records and fill in as people use the app.
- Documents: every document opens in the app and can be downloaded as Word (.docx) or Excel (.xlsx).
  Categories: Policy, Finance, Form, Notice, Minutes, Other. Finance includes the dues schedule, the
  annual budget, a live collection report (admin) and a live statement of account (resident).
  The administrator can import .docx, .xlsx, .csv, .txt/.md or .pdf files (Documents > Import file);
  Word/Excel/CSV/text files are readable in the app, PDFs can be downloaded back. In Finance the
  administrator can export the dues report and import an Excel/CSV list of paid units to record payments.
  The wording of the built-in documents is sample text: edit it in `lib/core/doc_seed.dart`.
- Imported documents live in memory like the rest of the data (they disappear when the app restarts).
- Finance documents are kept apart from the community documents: More > Finance documents (admin and
  resident). They hold the dues schedule, budget, collection report, payment history, statement of account
  and every receipt. Community documents (rules, forms, notices, minutes) no longer list finance files.
  Files the administrator imports under Finance documents are admin-only unless shared with residents.
- Announcements: with "Also text residents" on, the phone's messaging app opens with all resident mobile
  numbers (from Manage access) and the announcement typed in; the administrator taps Send. No SMS provider is needed.
- Finance > Charge adds a real one-off charge to a unit (it appears under the unit's dues and the resident's
  Dues & payment). The admin Home figures (units, residents, documents, bookings, earnings) come from the app data.
- Payments: residents see "How to pay" (office, bank transfer, GCash, Maya) under Dues & payment, send the
  reference number of their payment, and get a receipt once the administrator confirms it. Every receipt
  opens in the app and downloads as Word or Excel, and the payment history can be exported too. The
  administrator edits the account details (Finance > Payment options), checks proofs and records payments
  (Finance > Record payment). The account details are placeholders: add your real bank/e-wallet details.
  There is no online payment gateway: money is paid outside the app and recorded here as proof.
- Online payment is a SIMULATION: Dues & payment > "Pay online (simulation)" settles the resident's balance and issues a receipt marked "(simulated)" with a SIM-... reference. No real money moves. Connecting a real gateway (e.g. PayMongo) needs a merchant account and a backend server.
- Expenses (administrator only): Finance > Expenses, or More > Expenses. Every purchase of the corporation is encoded:
  what was bought, quantity, price of one, store or supplier, official receipt no., the facility or area it is for,
  category and date. The screen has a month picker, the month's total, a "where the money went" breakdown and the list
  of purchases. The Monthly expense report (summary, all purchases, spending by category against the monthly budget,
  spending by facility, change from last month) can be viewed and exported to Word or Excel for any month, and the
  current month also appears under Finance documents (admin only), next to the year-to-date Expense Report.
  The list starts empty.
- Profile: the administrator edits name, email, mobile number, photo and password under More > Settings (tap the avatar on the home screen or the profile card). Residents edit the same under More > Settings, including a profile photo. The administrator can also sign in with the email saved in the profile. Photos and changes are kept in memory only.
- The "Needs attention" cards on the administrator home are picture cards (ImageTile). The pictures are in assets/images (need_dues, need_bookings, need_units, need_grievances) and can be replaced with your own photos of the same name.

## Background photo

The City Residences building photo (`assets/images/building.png`) is the full-screen background of the login page. Inside the app it sits softly faded behind the dashboard tabs and sub-pages (`lib/widgets/backdrop.dart`). To make it clearer or fainter, change the two alpha numbers (`topVeil`, `midVeil`) in that file.

## Animations and layout

- `lib/widgets/motion.dart` holds the animations: page change (fade and slide), press effect on cards and buttons, numbers that count up, tabs that fade in when opened, a pulsing notification dot, and tiles that pop in one after another. The earnings chart draws itself from left to right.
- Home screens are grouped into titled sections with the same spacing (`DashSection` in `lib/widgets/common.dart`). Admin: quick actions, Overview, Needs attention, Finance, Calendar, Announcements, Upcoming facility bookings, Recent activity. Resident: quick actions, Overview, Quick access, My unit, Calendar, Announcements, Community events.
- The More tabs are grouped with small labels (`NavGroup`): Community / Money and files / Administration for the admin, My unit / Documents / Account for the resident.

