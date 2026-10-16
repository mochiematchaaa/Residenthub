# Step by step: open the database in Supabase

> In this GitHub repository the app is the repo root (`lib/`, `supabase/functions/`). `website/` means the repository mochiematchaaa/mochiematchaaa.github.io. The full package with all three parts is ResidentHub-System.zip.

Menu names in Supabase can look a little different over time, but the order of the steps stays the same.
Choose **A** to look at the real project, or **B** to make your own copy for testing (recommended for classmates).

---
## A. Look at the real project (the owner must invite you)

**Owner (the person who created the project):**
1. Go to https://supabase.com and sign in.
2. Open your **Organization**, then **Team**.
3. Click **Invite**, type your classmate's email and choose a role: **Read-only** or **Developer** for viewing and helping. Do not give **Owner** unless you trust the person completely.
4. Click **Send invitation**.

**Classmate:**
1. Open the invitation email and click **Accept invitation**. Sign in (or create a free Supabase account with the same email).
2. Choose the project **iexsitqmmhokmffmmaed** (ResidentHub).
3. Left menu **Table Editor**: you can see the tables `profiles` and `records`.
4. Left menu **SQL Editor**: run queries. Left menu **Authentication**: the list of accounts.
5. Be careful: this is the real data. Editing or deleting here changes the live system.

---
## B. Make your own copy (safe for testing)

### Step 1. Create the project
1. Go to https://supabase.com and **Sign up** (free). Sign in.
2. Click **New project**. Choose an organization, type a **Name** (for example `residenthub-test`), type a **Database password** (write it down, you will not need it again for this guide), pick the nearest **Region** (for example Singapore).
3. Click **Create new project** and wait 1 to 3 minutes until it says the project is ready.

### Step 2. Create the tables (run schema.sql)
1. Left menu **SQL Editor**, then **New query**.
2. Open `database/schema.sql` from this zip with any text editor (Notepad, VS Code). Select all (Ctrl+A) and copy (Ctrl+C).
3. Paste it into the SQL Editor and click **Run**. It should say *Success. No rows returned.*
4. Check: left menu **Table Editor**. You should see `profiles`, `records`, `verification_codes`, `reset_codes`.
   If you see a red error, copy the message and send it to the team. Do not run the file twice if the first run stopped in the middle; ask first.

### Step 3. Turn off public sign-up
1. Left menu **Authentication**, then **Sign In / Providers** (older name: Settings).
2. Turn **off** *Allow new users to sign up*. Click **Save**.
   (Only the administrator creates resident accounts, from inside the dashboard.)

### Step 4. Create the first administrator
1. Left menu **Authentication**, then **Users**, then **Add user**, then **Create new user**.
2. Type an email and a password. Tick **Auto Confirm User**. Click **Create user**.
3. Left menu **SQL Editor**, **New query**, paste this (change the email and the name), then **Run**:
   ```sql
   update public.profiles set role = 'admin', name = 'Your Name' where email = 'you@example.com';
   ```
   It should say 1 row affected. If it says 0 rows, the email is spelled differently from the user you created.

### Step 5. Deploy the 3 Edge Functions
They send the email codes and create/reset accounts. The code is in `supabase/functions/`: `manage-users`, `verify-contact`, `reset-password`.
1. Left menu **Edge Functions**, then **Deploy a new function** (choose **Via Editor** if asked).
2. Name it exactly `manage-users`. Delete the sample code, open `supabase/functions/manage-users/index.ts`, copy everything, paste it, click **Deploy**.
3. Repeat for `verify-contact` and `reset-password`.
4. Open each function's **Settings** (or the details tab) and set **Verify JWT**:
   - `manage-users`: **ON**
   - `verify-contact`: **ON**
   - `reset-password`: **OFF** (people who forgot their password are not signed in)
   (If you prefer the command line, the Supabase CLI can do the same: `supabase functions deploy manage-users`, and so on.)

### Step 6. Set the secrets (only for the email/text codes)
Skip this step if you only want to look around; sign-in will work but the email codes will not be sent.
1. **Project Settings**, then **Edge Functions**, then **Secrets** (or **Edge Functions**, then **Secrets**).
2. Add these, one by one (**name** exactly as written, **value** is yours):
   - `SMTP_HOST` = `smtp.gmail.com`
   - `SMTP_PORT` = `465`
   - `SMTP_USER` = your Gmail address
   - `SMTP_PASS` = a Google **App Password** (Google Account, Security, 2-Step Verification, App passwords). Never your normal password.
   - `SMTP_FROM` = the name/email shown to residents
   - Optional, for text messages: `SMS_PROVIDER` = `twilio` plus `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`; or `SMS_PROVIDER` = `semaphore` plus `SEMAPHORE_API_KEY`.
3. Nobody else, and no file in this zip, should ever contain these values.

### Step 7. Connect the website and the app to YOUR project
1. **Project Settings**, then **API** (or **API Keys**). Copy the **Project URL** and the **anon public** key.
   Never copy the `service_role` key into any file.
2. Website: open `supabase-config.js` (website repository) and replace the URL and the anon key.
3. App: open `lib/services/supabase_config.dart` and replace the URL and the anon key
   (or run it with `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).

### Step 8. Try it
1. Open the website folder with a small local server (`python3 -m http.server 8000` inside `website/`, or VS Code *Live Server*) and go to `http://localhost:8000/admin.html`.
2. Sign in with the administrator from Step 4.
3. Go to **Manage access** and create a resident account. The resident signs in at `resident.html`, chooses their own password, and confirms email/mobile with a code.

### Something wrong?
| Problem | Check |
|---|---|
| "Invalid login" for the admin | Step 4: was *Auto Confirm User* ticked and did the `update` say 1 row? |
| Admin sees an empty/blocked page | Step 4 `update` not applied (role is still `resident`) |
| Cannot create resident accounts | Step 5: `manage-users` deployed with *Verify JWT* ON? |
| Codes are never received | Step 6 secrets, and `verify-contact` deployed? |
| "Forgot password" fails | `reset-password` deployed with *Verify JWT* OFF? |
| Data does not appear after login | Step 7: URL and anon key belong to the same project? |
