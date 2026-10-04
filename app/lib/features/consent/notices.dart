/// Every consent notice and permission rationale shown to the user, in one place
/// so it can be reviewed as a whole.
///
/// Change [noticeVersion] whenever the meaning of any notice changes. The version
/// the user saw is stored with every consent on the server.
library;

import '../../data/models.dart';

/// Sent as `notice_version` with every consent change (max 20 characters).
const noticeVersion = '2026-10-v1';

class Notice {
  const Notice({required this.title, required this.summary, required this.points, this.withdrawal});

  final String title;

  /// One or two sentences: what the user is agreeing to.
  final String summary;

  /// What it means in practice, as short separate statements.
  final List<String> points;

  /// What happens when the consent is switched off later.
  final String? withdrawal;
}

// --- C1: private analytics (required to use the app) --------------------------

const privateAnalyticsNotice = Notice(
  title: 'Track your own spending',
  summary: 'ForReal reads the payment messages your bank sends you and keeps a record of who you paid, '
      'roughly how much, and what you bought.',
  points: [
    'Only messages from banks are read. Personal messages, OTPs and everything else are ignored and never stored.',
    'The message text and the exact amount stay on this phone. They are never uploaded.',
    'Our server receives: the name of who you paid, the date, the part of the day, an amount range '
        '(for example ₹200 to 500), and a scrambled form of the bank reference number that cannot be turned back.',
    'Your bank balance and account number are never read or stored.',
    'This record is private to you. Nobody else sees it unless you separately choose to contribute to community rankings.',
  ],
  withdrawal: 'If you switch this off, ForReal stops reading bank messages and deletes your payments '
      'and your shop answers from our server and from this phone. Community rankings and location are switched off with it.',
);


// --- C2: community rankings -----------------------------------------------------

const communityRankingsNotice = Notice(
  title: 'Contribute to community rankings',
  summary: 'Let your payments to shops count, anonymously, towards rankings of popular shops and items in your area.',
  points: [
    'Only payments to places you confirmed as shops are counted. Payments to people are never shared.',
    'You are anonymous by default: your name and phone number are never shown to other users.',
    'Your answers also help others: when enough people confirm the same shop for a payee, ForReal suggests it to others nearby.',
    'What is counted is the shop, the items, the date and the amount range. Never the exact amount.',
  ],
  withdrawal: 'If you switch this off, your payments stop counting from that moment. '
      'Show my name and merchant insights are switched off with it.',
);

// --- C3: show my name (settings only) ----------------------------------------------

const showNameNotice = Notice(
  title: 'Show my name',
  summary: 'Show the display name you choose next to your contributions, instead of being anonymous.',
  points: [
    'Off by default. Without it you appear as an anonymous contributor.',
    'Only the display name you type is shown. Your phone number is never shown.',
    'Needs community rankings to be on.',
  ],
  withdrawal: 'If you switch this off, you are anonymous again.',
);

// --- C4: location -----------------------------------------------------------------

const locationNotice = Notice(
  title: 'Use approximate location',
  summary: 'Your approximate location is used to identify which shop you paid, and to name the area the shop is in.',
  points: [
    'Only an approximate location is used, rounded to about 100 metres. ForReal never asks for your precise location.',
    'Location is read only while the app is open on screen. Never in the background.',
    'The rounded location is stored with the payment on our server while this consent is on.',
    'To name the area (for example "Sector 62, Noida"), the rounded location is sent to OpenStreetMap. '
        'Only the rounded coordinates are sent: nothing about you or your payment.',
  ],
  withdrawal: 'If you switch this off, the locations stored with your payments and shop answers are erased from our server.',
);

// --- C5: merchant insights -----------------------------------------------------------

const merchantInsightsNotice = Notice(
  title: 'Contribute to merchant insights',
  summary: 'Let your payments count, anonymously and only as part of a group, in statistics a shop can see about itself.',
  points: [
    'A shop sees totals only, such as how many customers bought tea in the evening. Never who you are.',
    'Nothing is shown to a shop unless enough different customers are in the group.',
    'Needs community rankings to be on.',
  ],
  withdrawal: 'If you switch this off, your payments stop counting towards merchant insights.',
);



// --- short copy on the screens ---------------------------------------------------
//
// The screens show these short lines; the full notice above is one tap away
// ("Read the full notice" in onboarding, a tap on the row under You) and is what
// the user agrees to.

/// Name and one-liner of each consent under "You".
const consentLabels = <Purpose, ({String title, String line})>{
  Purpose.privateAnalytics: (title: 'Payment messages', line: 'Needed for the app to work'),
  Purpose.communityRankings: (title: 'Community rankings', line: 'Your shop visits, counted without your name'),
  Purpose.showName: (title: 'Show my name', line: 'Let others see you paid at a shop'),
  Purpose.location: (title: 'Location', line: 'Rough area, only while the app is open'),
  Purpose.merchantInsights: (title: 'Insights for shops', line: 'Anonymous trends for shop owners'),
};

/// One onboarding step: heading, supporting line, and its short reassurances.
class StepCopy {
  const StepCopy({required this.title, required this.subtitle, this.points = const []});

  final String title;
  final String subtitle;

  /// (heading, detail). The heading is empty for a plain one-line point.
  final List<(String, String)> points;
}

/// Step 1. Covers the private-analytics consent and the Android SMS permission
/// (RECEIVE_SMS and READ_SMS) that follows it.
const paymentMessagesStep = StepCopy(
  title: 'Let ForReal read your payment messages',
  subtitle: 'This is the one thing the app needs to work.',
  points: [
    ('Only bank payment alerts', 'Messages from bank senders. Nothing else is opened.'),
    ('Stays on your phone', 'The message text and exact amounts never leave it.'),
    ('Never read', 'OTPs, chats, promotions, or anything personal.'),
  ],
);

const paymentMessagesRequired = 'Without payment messages there is nothing for the app to show. '
    'You can allow it now, or sign out and come back later.';

/// Step 2.
const communityStep = StepCopy(
  title: 'Count me in, anonymously',
  subtitle: 'Your visits help rank shops. Nobody sees it was you.',
  points: [
    ('Community rankings', 'Add my shop visits to counts like “142 people paid here”.'),
    ('Insights for shops', 'Include my visits in anonymous trends shop owners can see.'),
    ('', 'Payments to people are never counted or shared.'),
  ],
);

/// Step 3. Must say that the rounded location goes to OpenStreetMap.
const locationStep = StepCopy(
  title: 'Find the shop you just paid',
  subtitle: 'Your rough location tells “Ramesh Kumar” the tea stall from the one across town.',
  points: [
    ('', 'Approximate only, to about 100 metres'),
    ('', 'Only while the app is open, never in the background'),
    ('', 'Sent rounded to OpenStreetMap to name the area'),
  ],
);

/// Step 4. The numbers here are the app's actual limits (PromptService).
const notificationsStep = StepCopy(
  title: 'One tap after you pay',
  subtitle: 'A quick question right after a payment, so you never have to open the app.',
  points: [
    ('', 'At most 6 a day, the rest wait for one evening summary'),
    ('', 'Stops asking once it has learned a shop'),
  ],
);

/// Step 5.
const historyStep = StepCopy(
  title: 'Bring in past payments?',
  subtitle: 'Start with your history so the app is useful on day one. No notifications for old ones.',
  points: [
    ('Last month', 'About 80 to 120 payments for most people.'),
    ('Last 3 months', 'More to label, better guesses from the start.'),
    ('Start fresh', 'Only payments from now on.'),
  ],
);

/// Shown while new payments are not being recorded.
const captureOffTitle = 'Capture is off';
const captureOffNeedsSms = 'Allow SMS access so payments show up on their own.';
const captureOffNeedsSettings = 'Allow SMS access in app settings so payments show up on their own.';
const captureOffNeedsConsent = 'Turn on payment messages so payments show up on their own.';

/// Shown wherever area names from OpenStreetMap appear.
const osmAttribution = '© OpenStreetMap contributors';

Notice noticeFor(Purpose purpose) => switch (purpose) {
      Purpose.privateAnalytics => privateAnalyticsNotice,
      Purpose.communityRankings => communityRankingsNotice,
      Purpose.showName => showNameNotice,
      Purpose.location => locationNotice,
      Purpose.merchantInsights => merchantInsightsNotice,
    };

/// Confirmations for irreversible actions.
const deleteAccountWarning = 'This permanently deletes your account, your payments, your shop answers and your consent '
    'history from our server, and everything stored on this phone. Shops you added stay, without your name. '
    'This cannot be undone.';

const signOutWarning = 'Signing out removes your payments, exact amounts and settings from this phone. '
    'Your account and the payments on our server are kept. Exact amounts are stored only on this phone and cannot be restored.';

const withdrawPrivateAnalyticsWarning = 'ForReal will stop reading bank messages and will delete all your payments and '
    'shop answers from our server and this phone. This cannot be undone.';
