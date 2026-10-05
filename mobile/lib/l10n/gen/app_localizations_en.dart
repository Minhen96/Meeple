// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Meeple';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSend => 'Send';

  @override
  String get commonShare => 'Share';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonOops => 'Oops!';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonMore => 'More';

  @override
  String get commonReadMore => 'Read more';

  @override
  String get commonShowLess => 'Show less';

  @override
  String get commonDeletedUser => 'Deleted User';

  @override
  String get loadingMore => 'Loading more…';

  @override
  String get allCaughtUp => 'You\'re all caught up!';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get backOnline => 'Back online';

  @override
  String staleData(String age) {
    return 'Showing cached data from $age';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet connection. Please check your network.';

  @override
  String get errorTimeout => 'Request timed out. Please try again.';

  @override
  String get errorOffline => 'You\'re offline. Try again when you reconnect.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get errorForbidden => 'You do not have permission to do that.';

  @override
  String get errorNotFound => 'This doesn\'t exist or was removed.';

  @override
  String get errorRateLimit =>
      'Too many requests. Please slow down and try again.';

  @override
  String get errorServiceUnavailable =>
      'This service is temporarily unavailable. Please try again later.';

  @override
  String get errorServer =>
      'Something went wrong on our end. Please try again later.';

  @override
  String get errorEditWindowExpired => 'This can no longer be edited.';

  @override
  String get errorEventCancelled => 'This event has been cancelled.';

  @override
  String get errorEventCompleted => 'This event has already ended.';

  @override
  String get errorEventFull => 'This event is full.';

  @override
  String get errorNotHost => 'Only the host can do that.';

  @override
  String get errorNotFriends => 'You can only do that with friends.';

  @override
  String get errorRequestCooldown =>
      'Please wait before sending another friend request.';

  @override
  String get errorPendingLimit => 'You have too many pending friend requests.';

  @override
  String get errorReportLimit => 'You\'ve reached today\'s report limit.';

  @override
  String get errorBggUserNotFound =>
      'BGG username not found. Check the spelling.';

  @override
  String get errorBggUnavailable =>
      'BGG is currently slow. Skip for now and try again later.';

  @override
  String get errorUsernameTooSoon =>
      'You can only change your username once every 30 days.';

  @override
  String get errorUsernameTaken => 'Username already taken';

  @override
  String get errorEmailTaken => 'Email already registered';

  @override
  String get errorAccountDeleted => 'This account is scheduled for deletion.';

  @override
  String get errorGoogleEmailNotVerified =>
      'Your Google email address is not verified.';

  @override
  String get errorGoogleAccountConflict =>
      'This email is already registered with a password. Sign in with your password instead.';

  @override
  String get errorGoogleFailed => 'Google sign-in failed. Please try again.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get aiRateLimit =>
      'You\'ve reached the 20 questions/day limit. Resets at midnight UTC.';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navEvents => 'Events';

  @override
  String get navProfile => 'Profile';

  @override
  String get createTitle => 'Create';

  @override
  String get createPost => 'Post a game night';

  @override
  String get createEvent => 'Host an event';

  @override
  String get createAddGame => 'Add a game';

  @override
  String get createFindMatch => 'Find players';

  @override
  String get pushPromptTitle => 'Stay in the loop about your game nights';

  @override
  String get pushPromptBody =>
      'Get notified about invites, reminders, friend requests and new comments.';

  @override
  String get pushPromptAllow => 'Allow Notifications';

  @override
  String get pushPromptNotNow => 'Not now';

  @override
  String get pushChannelEvents => 'Events & Game Nights';

  @override
  String get pushChannelEventsDescription =>
      'Invites, reminders, and match notifications';

  @override
  String get pushChannelSocial => 'Social Activity';

  @override
  String get pushChannelSocialDescription =>
      'Likes, comments, and friend requests';

  @override
  String get appLockedTitle => 'Meeple is locked';

  @override
  String get appLockedBody => 'Unlock with biometrics or your device passcode.';

  @override
  String get appLockedUnlock => 'Unlock';

  @override
  String get biometricReasonUnlock => 'Unlock Meeple';

  @override
  String get biometricReasonEnable =>
      'Verify your identity to enable the app lock';

  @override
  String activityCollectionAdd(String name, String game) {
    return '$name added $game to their collection.';
  }

  @override
  String activityEventCreated(String name, String event) {
    return '$name is hosting $event.';
  }

  @override
  String activityEventJoined(String name, String event) {
    return '$name joined $event.';
  }

  @override
  String activityGeneric(String name) {
    return '$name has new activity';
  }

  @override
  String get aiAskAnyway => 'Ask anyway';

  @override
  String get aiDisclaimer => 'AI-generated answers may not be 100% accurate.';

  @override
  String get aiError => 'Something went wrong. Try again.';

  @override
  String get aiInputHint => 'Ask a question...';

  @override
  String aiNoRulebook(String game) {
    return 'No rulebook available for $game yet.';
  }

  @override
  String get aiNoRulebookBody =>
      'Answers will be based on general knowledge and may be less accurate.';

  @override
  String get aiNoRulebookTooltip => 'No rulebook uploaded yet';

  @override
  String get aiPromptSetup => 'Setup instructions';

  @override
  String get aiPromptTurn => 'What happens on your turn?';

  @override
  String get aiPromptWin => 'How do you win?';

  @override
  String get aiRulesAssistant => 'AI Rules Assistant';

  @override
  String aiSheetTitle(String game) {
    return '$game Rules Assistant';
  }

  @override
  String get authBackToSignIn => 'Back to Sign In';

  @override
  String get authCheckInbox => 'Check your inbox';

  @override
  String get authConfirmNewPassword => 'Confirm new password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authCreateAccountTitle => 'Create your account';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authEmailOrUsername => 'Email or username';

  @override
  String get authEmailOrUsernameRequired =>
      'Please enter your email or username';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authForgotBody =>
      'Enter the email you registered with and we\'ll send you a reset link.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotTitle => 'Reset your password';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authInvalidEmail => 'Enter a valid email address';

  @override
  String get authIveVerified => 'I\'ve Verified My Email';

  @override
  String get authJoin => 'Join the Meeple community';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authNewPasswordHint =>
      'Your new password must be at least 8 characters.';

  @override
  String get authNewPasswordTitle => 'New Password';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authOr => 'or';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordLength => 'Must be 8–128 characters';

  @override
  String get authPasswordMin => 'Must be at least 8 characters';

  @override
  String get authPasswordRequired => 'Please enter your password';

  @override
  String get authPasswordUpdated => 'Password updated!';

  @override
  String get authPasswordUpdatedBody =>
      'Your password has been reset. Sign in with your new password.';

  @override
  String get authPasswordsMismatch => 'Passwords don\'t match';

  @override
  String get authResendEmail => 'Resend Email';

  @override
  String get authResetLinkExpired =>
      'This link has expired. Request a new one.';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String authResetSentTo(String email) {
    return 'If $email is registered, you\'ll receive a reset link.';
  }

  @override
  String get authSendResetLink => 'Send Reset Link';

  @override
  String get authSetNewPassword => 'Create a new password';

  @override
  String get authSignIn => 'Log In';

  @override
  String get authSignInLink => 'Log in';

  @override
  String get authSignInSubtitle => 'Welcome back';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authTermsNote =>
      'By creating an account you agree to our Terms of Service and Privacy Policy.';

  @override
  String get authUsernameLength =>
      '3–20 lowercase letters, numbers or underscores';

  @override
  String get authUsernameRequired => 'Username is required';

  @override
  String get authVerificationResent => 'Email resent!';

  @override
  String get authVerifyBody =>
      'Click the link in the email to activate your account.';

  @override
  String get authVerifyFirst => 'Please verify your email first.';

  @override
  String authVerifySentTo(String email) {
    return 'We sent a verification link to $email';
  }

  @override
  String get avatarChange => 'Change profile photo';

  @override
  String get avatarCropTitle => 'Crop Photo';

  @override
  String get avatarUploadFailed => 'Upload failed. Try again.';

  @override
  String get badgeFavorited => 'Favorite';

  @override
  String get badgeOwned => 'Owned';

  @override
  String get badgeWishlisted => 'On wishlist';

  @override
  String get bggImportBody =>
      'Enter your BoardGameGeek username to import your collection.';

  @override
  String bggImportDone(int imported, int skipped, int failed) {
    return 'Imported $imported games ($skipped skipped, $failed failed).';
  }

  @override
  String get bggImportFailed => 'The import failed. Please try again.';

  @override
  String bggImportProgress(int processed, int total) {
    return 'Importing… $processed of $total games';
  }

  @override
  String get bggImportStart => 'Import Collection';

  @override
  String get bggImportStarting => 'Starting import…';

  @override
  String get bggImportTitle => 'Import your collection';

  @override
  String get bggPrivacyNote => 'We only read your public collection.';

  @override
  String get bggUsername => 'BGG username';

  @override
  String get blockedEmpty => 'You haven\'t blocked anyone.';

  @override
  String get blockedTitle => 'Blocked users';

  @override
  String get bookmarksEmptyBody =>
      'Tap the bookmark on a post to save it here.';

  @override
  String get bookmarksEmptyTitle => 'No saved posts yet';

  @override
  String get bookmarksTitle => 'Saved posts';

  @override
  String get changeEmailBody =>
      'We\'ll send a verification link to your new address. Your email changes once you confirm it.';

  @override
  String get changeEmailCurrentPassword => 'Current password';

  @override
  String get changeEmailNew => 'New email';

  @override
  String changeEmailSentBody(String email) {
    return 'Open the link we sent to $email to confirm the change.';
  }

  @override
  String get changeEmailSentTitle => 'Check your new inbox';

  @override
  String get changeEmailSubmit => 'Send verification link';

  @override
  String changePasswordBody(String email) {
    return 'For your security, password changes go through email. We\'ll send a reset link to $email.';
  }

  @override
  String get changePasswordNoEmail =>
      'Request a reset link with the email you registered with.';

  @override
  String get changePasswordSend => 'Send reset link';

  @override
  String get changePasswordSentBody =>
      'Follow the link in the email to choose a new password.';

  @override
  String get changePasswordSentTitle => 'Reset link sent';

  @override
  String get collectionNoPlays => 'No plays logged yet.';

  @override
  String get collectionNotes => 'Notes';

  @override
  String get collectionPlayHistory => 'Play history';

  @override
  String collectionRating(String rating) {
    return 'Your rating: $rating';
  }

  @override
  String get collectionRemove => 'Remove from collection';

  @override
  String collectionRemoveMessage(String game) {
    return '$game will be removed from your collection, wishlist and favorites.';
  }

  @override
  String get collectionRemoveTitle => 'Remove this game?';

  @override
  String get commentDeleteMessage => 'This comment will be removed.';

  @override
  String get commentDeleteTitle => 'Delete comment?';

  @override
  String get commentEditTitle => 'Edit comment';

  @override
  String get deleteConfirmMessage =>
      'This will delete your account. You have 30 days to reactivate it by logging in again.';

  @override
  String get deleteConfirmTitle => 'Are you absolutely sure?';

  @override
  String get deleteDone => 'Your account is scheduled for deletion.';

  @override
  String get deletePasswordless => 'I signed up with Google (no password)';

  @override
  String get deleteSubmit => 'Delete My Account';

  @override
  String get deleteTypeConfirm => 'Type DELETE to confirm';

  @override
  String get deleteTypeConfirmError => 'Please type DELETE';

  @override
  String get deleteWarning =>
      'Your account will be deactivated immediately and permanently deleted after 30 days. Your collection, friendships, match requests and notifications are removed now; posts and comments show as \"Deleted User\". Log in within 30 days to reactivate.';

  @override
  String get eventAccept => 'Accept';

  @override
  String get eventCancelConfirm => 'Cancel event';

  @override
  String get eventCancelMessage =>
      'Everyone who joined or was invited will be notified.';

  @override
  String get eventCancelTitle => 'Cancel this event?';

  @override
  String get eventCancelledBanner => 'This event has been cancelled.';

  @override
  String get eventChangeToGoing => 'Change to Going';

  @override
  String get eventChooseFriends => 'Choose friends';

  @override
  String get eventCreated => 'Event created!';

  @override
  String get eventCreatedInvites => 'Event created! Invites sent.';

  @override
  String get eventDateInPast => 'Please choose a future date.';

  @override
  String get eventDateRequired => 'Please pick a date and time.';

  @override
  String get eventDecline => 'Decline';

  @override
  String eventDefaultTitle(String game) {
    return '$game Night';
  }

  @override
  String get eventEdit => 'Edit event';

  @override
  String get eventEndedBanner => 'This event has ended.';

  @override
  String get eventFieldDateTime => 'Date & time';

  @override
  String get eventFieldDescription => 'Description (optional)';

  @override
  String get eventFieldGame => 'Game';

  @override
  String get eventFieldLocation => 'Location';

  @override
  String get eventFieldMaxPlayers => 'Max players';

  @override
  String get eventFieldTitle => 'Event title';

  @override
  String get eventFieldVisibility => 'Who can see it';

  @override
  String get eventFull => 'Event is Full';

  @override
  String eventGoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count going',
      one: '1 going',
    );
    return '$_temp0';
  }

  @override
  String eventHostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String get eventInviteFriends => 'Invite friends';

  @override
  String eventInvitedCount(int count) {
    return '$count invited';
  }

  @override
  String get eventInvitesSent => 'Invites sent.';

  @override
  String get eventJoin => 'Join';

  @override
  String get eventJoined => 'You\'re going!';

  @override
  String get eventKick => 'Remove';

  @override
  String eventKickMessage(String name) {
    return '$name will be removed from this event.';
  }

  @override
  String get eventKickTitle => 'Remove participant?';

  @override
  String get eventLeave => 'Leave Event';

  @override
  String get eventLeaveMessage => 'Your spot will open up for someone else.';

  @override
  String get eventLeaveTitle => 'Leave this event?';

  @override
  String get eventLocationHint => 'Address, venue name, or \'Online\'';

  @override
  String get eventManage => 'Manage Event';

  @override
  String get eventNoMemories => 'No memories shared yet.';

  @override
  String get eventNotFound => 'This event doesn\'t exist or was removed.';

  @override
  String get eventPickDate => 'Pick date';

  @override
  String get eventPickGame => 'Search for a game';

  @override
  String get eventPickTime => 'Pick time';

  @override
  String eventPlayersCount(int count, int max) {
    return '$count/$max players';
  }

  @override
  String get eventRemoveGame => 'Remove game';

  @override
  String get eventStatusCancelled => 'Cancelled';

  @override
  String get eventStatusCompleted => 'Completed';

  @override
  String get eventStatusFull => 'Full';

  @override
  String get eventStatusOpen => 'Open';

  @override
  String get eventTitleTooShort => 'Title must be at least 3 characters';

  @override
  String get eventUpdated => 'Event updated.';

  @override
  String get eventViewMemories => 'View Memories';

  @override
  String get eventYouWereRemoved => 'The host removed you from this event.';

  @override
  String get eventsCalendarView => 'Calendar view';

  @override
  String get eventsEmptyPastBody => 'Your game night history will appear here.';

  @override
  String get eventsEmptyPastTitle => 'No past events.';

  @override
  String get eventsEmptyUpcomingBody => 'Host your next game night!';

  @override
  String get eventsEmptyUpcomingTitle => 'No upcoming events.';

  @override
  String get eventsListView => 'List view';

  @override
  String get eventsNoneThisMonth => 'No events this month.';

  @override
  String get eventsTabMine => 'Mine';

  @override
  String get eventsTabPast => 'Past';

  @override
  String get eventsTabUpcoming => 'Upcoming';

  @override
  String get eventsTitle => 'Events';

  @override
  String get filter1to2h => '1–2h';

  @override
  String get filter30to60 => '30–60m';

  @override
  String get filterHeavy => 'Heavy';

  @override
  String get filterLight => 'Light';

  @override
  String get filterMedium => 'Medium';

  @override
  String get filterOver2h => '2h+';

  @override
  String filterPlayers(int count) {
    return '$count+ players';
  }

  @override
  String get filterUnder30 => '< 30m';

  @override
  String get friendAccept => 'Accept';

  @override
  String get friendAdd => 'Add Friend';

  @override
  String get friendCancelMessage => 'Your friend request will be withdrawn.';

  @override
  String get friendCancelRequest => 'Cancel request';

  @override
  String get friendCancelTitle => 'Cancel friend request?';

  @override
  String get friendDecline => 'Decline';

  @override
  String get friendFriends => 'Friends';

  @override
  String get friendPending => 'Pending';

  @override
  String friendPickerDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done ($count)',
      zero: 'Done',
    );
    return '$_temp0';
  }

  @override
  String get friendPickerEmpty => 'No friends to show.';

  @override
  String get friendPickerSearch => 'Search friends';

  @override
  String get friendRequestSent => 'Friend request sent.';

  @override
  String get friendUnblock => 'Unblock';

  @override
  String get friendUnfriend => 'Unfriend';

  @override
  String get friendUnfriendMessage =>
      'You will no longer see each other\'s friends-only content.';

  @override
  String get friendUnfriendTitle => 'Remove friend?';

  @override
  String get friendsEmptyBody =>
      'Find people you play with and add them as friends.';

  @override
  String get friendsEmptyTitle => 'No friends yet';

  @override
  String get friendsNoRequests => 'No pending friend requests.';

  @override
  String get friendsNoSuggestions =>
      'No suggestions yet. Search for friends by username.';

  @override
  String get friendsReceived => 'Received';

  @override
  String get friendsSearchHint => 'Search by name or username';

  @override
  String get friendsSent => 'Sent';

  @override
  String get friendsSuggestions => 'People you may know';

  @override
  String get friendsTabFind => 'Find';

  @override
  String get friendsTabFriends => 'Friends';

  @override
  String get friendsTabRequests => 'Requests';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get gameAddToCollection => 'Add to Collection';

  @override
  String get gameAddedToCollection => 'Added to collection!';

  @override
  String get gameBackToLibrary => 'Back to Library';

  @override
  String gameBggRating(String rating) {
    return 'BGG rating $rating';
  }

  @override
  String get gameCategories => 'Categories';

  @override
  String get gameFavorite => 'Add to favorites';

  @override
  String gameFriendRating(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '1 friend',
    );
    return '$rating avg from $_temp0';
  }

  @override
  String get gameInCollection => 'In Collection';

  @override
  String get gameInfoComplexity => 'Weight';

  @override
  String get gameInfoDuration => 'Duration';

  @override
  String get gameInfoPlayers => 'Players';

  @override
  String get gameLogPlay => 'Log a play';

  @override
  String get gameMechanics => 'Mechanics';

  @override
  String gameMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get gameNoFriendsOwn => 'None of your friends own this yet.';

  @override
  String get gameNoReviews => 'No reviews from friends yet.';

  @override
  String get gameNoSessions => 'No sessions logged yet.';

  @override
  String get gameNotFound => 'This game doesn\'t exist or was removed.';

  @override
  String get gameOnWishlist => 'On Wishlist';

  @override
  String gameOwnedByFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Owned by $count friends',
      one: 'Owned by 1 friend',
    );
    return '$_temp0';
  }

  @override
  String gamePlayers(String range) {
    return '$range players';
  }

  @override
  String gamePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String get gameTabFriends => 'Friends';

  @override
  String get gameTabOverview => 'Overview';

  @override
  String get gameTabReviews => 'Reviews';

  @override
  String get gameTabSessions => 'Sessions';

  @override
  String get gameUnfavorite => 'Remove from favorites';

  @override
  String get gameWishlist => 'Wishlist';

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name!';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name!';
  }

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name!';
  }

  @override
  String greetingNextSession(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Your next session is in $days days.',
      one: 'Your next session is tomorrow.',
      zero: 'Your next session is today.',
    );
    return '$_temp0';
  }

  @override
  String get greetingNoEvents => 'No upcoming events.';

  @override
  String get homeCreatePost => 'Create a Post';

  @override
  String get homeEmptyBody => 'Your friends haven\'t posted recently.';

  @override
  String get homeEmptyNoFriendsBody =>
      'Add friends to see what they\'re playing.';

  @override
  String get homeEmptyNoFriendsTitle => 'Your feed is quiet.';

  @override
  String get homeEmptyTitle => 'Nothing new yet.';

  @override
  String get homeFeedError => 'Couldn\'t load your feed.';

  @override
  String get homeFeedTitle => 'Activity';

  @override
  String get homeFindFriends => 'Find Friends';

  @override
  String get homeMatchesTitle => 'Match suggestions';

  @override
  String homeMoreMatches(int count) {
    return '+$count more';
  }

  @override
  String get homeUpcomingTitle => 'Upcoming';

  @override
  String get homeViewCalendar => 'View Calendar';

  @override
  String get htpActions => 'Actions';

  @override
  String get htpEnd => 'End of game';

  @override
  String get htpFailed => 'The guide could not be generated.';

  @override
  String get htpFaq => 'FAQ';

  @override
  String get htpGenerate => 'Generate guide';

  @override
  String htpGenerating(int progress) {
    return 'Generating… $progress%';
  }

  @override
  String get htpNotGenerated => 'No How to Play guide yet.';

  @override
  String get htpObjective => 'Objective';

  @override
  String get htpOverview => 'Overview';

  @override
  String get htpResources => 'Resources';

  @override
  String get htpRules => 'Rules';

  @override
  String get htpScoring => 'Scoring';

  @override
  String get htpSetup => 'Setup';

  @override
  String get htpTips => 'Tips';

  @override
  String get htpTitle => 'How to Play';

  @override
  String get htpTurns => 'Turns';

  @override
  String get htpUnavailable => 'The guide is unavailable right now.';

  @override
  String get htpWinning => 'Winning';

  @override
  String get libraryBrowseGames => 'Browse Games';

  @override
  String get libraryDatabaseUnavailable => 'Game database unavailable.';

  @override
  String get libraryEmptyCollectionBody =>
      'Search for games to add to your collection.';

  @override
  String get libraryEmptyCollectionTitle => 'Your shelf is empty.';

  @override
  String get libraryEmptyFavoritesBody => 'Favorite a game you love.';

  @override
  String get libraryEmptyFavoritesTitle => 'No favorites yet.';

  @override
  String get libraryEmptyWishlistBody =>
      'Browse the library and add games you want.';

  @override
  String get libraryEmptyWishlistTitle => 'No games on your wishlist yet.';

  @override
  String get libraryNoGames => 'No games to show.';

  @override
  String libraryNoResults(String query) {
    return 'No games found for \'$query\'.';
  }

  @override
  String get libraryNoResultsHint =>
      'Try a different spelling or fewer filters.';

  @override
  String get librarySearchHint => 'Search games';

  @override
  String get libraryTabAll => 'All Games';

  @override
  String get libraryTabCollection => 'My Collection';

  @override
  String get libraryTabFavorites => 'Favorites';

  @override
  String get libraryTabWishlist => 'Wishlist';

  @override
  String get libraryTitle => 'Library';

  @override
  String get matchActiveRequests => 'Active requests';

  @override
  String get matchAvailableFrom => 'Available from';

  @override
  String matchAvailableRange(String from, String to) {
    return 'Available $from – $to';
  }

  @override
  String get matchAvailableUntil => 'Available until';

  @override
  String get matchDismiss => 'Dismiss';

  @override
  String get matchFormBody =>
      'We\'ll match you with friends who want to play the same game at the same time.';

  @override
  String get matchFormTitle => 'Find players';

  @override
  String matchFriendsWantToPlay(int count, String game) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends want to play $game',
      one: '1 friend wants to play $game',
    );
    return '$_temp0';
  }

  @override
  String matchFromValue(String time) {
    return 'From $time';
  }

  @override
  String get matchInvalidRange => 'The end must be after the start.';

  @override
  String get matchNoRequests => 'No active match requests.';

  @override
  String get matchNoSuggestions => 'No match suggestions right now.';

  @override
  String get matchPickGameFirst => 'Pick a game first.';

  @override
  String get matchRequestCreated => 'Match request created.';

  @override
  String get matchSubmit => 'Let\'s Play!';

  @override
  String matchUntilValue(String time) {
    return 'Until $time';
  }

  @override
  String get matchingTitle => 'Matching';

  @override
  String get minutesSuffix => 'min';

  @override
  String notifBggImportCompleted(int count) {
    return 'Your BGG import finished: $count games added.';
  }

  @override
  String notifCommentMention(String name) {
    return '$name mentioned you in a comment';
  }

  @override
  String notifEventCancelled(String event) {
    return '$event was cancelled';
  }

  @override
  String notifEventCompleted(String event) {
    return '$event has ended. Share your memories!';
  }

  @override
  String notifEventInvite(String name, String event) {
    return '$name invited you to $event';
  }

  @override
  String notifEventKicked(String event) {
    return 'You were removed from $event';
  }

  @override
  String notifEventLeave(String name, String event) {
    return '$name left $event';
  }

  @override
  String notifEventReminder(String event) {
    return '$event starts soon';
  }

  @override
  String notifEventRsvp(String name, String event) {
    return '$name is going to $event';
  }

  @override
  String notifEventUpdated(String event) {
    return '$event was updated';
  }

  @override
  String notifFriendAccepted(String name) {
    return '$name accepted your friend request';
  }

  @override
  String notifFriendRequest(String name) {
    return '$name sent you a friend request';
  }

  @override
  String notifMatchAccepted(String name, String game) {
    return '$name accepted the match for $game';
  }

  @override
  String notifMatchFound(String game) {
    return 'New match found for $game';
  }

  @override
  String notifPostComment(String name) {
    return '$name commented on your post';
  }

  @override
  String notifPostLike(String name) {
    return '$name liked your post';
  }

  @override
  String notifPostTag(String name) {
    return '$name tagged you in a post';
  }

  @override
  String notifRuleNoteApproved(String game) {
    return 'Your rule note for $game was approved';
  }

  @override
  String notifRuleNoteRejected(String game) {
    return 'Your rule note for $game was rejected';
  }

  @override
  String notifRulebookApproved(String game) {
    return 'The rulebook for $game was approved';
  }

  @override
  String notifRulebookRejected(String game) {
    return 'The rulebook for $game was rejected';
  }

  @override
  String notifRulebookUnderReview(String game) {
    return 'The rulebook for $game is under review';
  }

  @override
  String get notificationAGame => 'a game';

  @override
  String get notificationAnEvent => 'an event';

  @override
  String get notificationPrefsTitle => 'Notification preferences';

  @override
  String get notificationSomeone => 'Someone';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String get notificationsEmptyBody => 'Notifications will appear here.';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsMarkRead => 'Mark as read';

  @override
  String get notificationsThisWeek => 'This Week';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsToday => 'Today';

  @override
  String get onboardingAddGameBody => 'Add a few games you own to get started.';

  @override
  String onboardingAddGameConfirm(String game) {
    return 'Add $game to your collection?';
  }

  @override
  String get onboardingAddGameTitle => 'What do you love to play?';

  @override
  String get onboardingBggBody =>
      'Already on BoardGameGeek? Bring your collection over.';

  @override
  String get onboardingBggTitle => 'Import from BoardGameGeek';

  @override
  String get onboardingFinish => 'Finish';

  @override
  String get onboardingFriendsBody =>
      'Send friend requests to people you play with.';

  @override
  String get onboardingFriendsTitle => 'Find your friends';

  @override
  String get onboardingPopular => 'Popular games';

  @override
  String get onboardingProfileBody =>
      'Add a photo and a name so friends recognise you.';

  @override
  String get onboardingProfileTitle => 'Set up your profile';

  @override
  String get playDate => 'Date played';

  @override
  String get playDuration => 'Duration';

  @override
  String get playFewerPlayers => 'Fewer';

  @override
  String playLogTitle(String game) {
    return 'Log a play of $game';
  }

  @override
  String get playLogged => 'Play logged!';

  @override
  String get playMorePlayers => 'More';

  @override
  String get playNotes => 'Notes (optional)';

  @override
  String get playPlayers => 'Players';

  @override
  String get postAddComment => 'Add a comment…';

  @override
  String get postAddPhotos => 'Add Photos';

  @override
  String get postCaptionHint => 'What happened at the table?';

  @override
  String get postComment => 'Comment';

  @override
  String postCommentsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'Comments',
    );
    return '$_temp0';
  }

  @override
  String get postCompressing => 'Compressing…';

  @override
  String get postDelete => 'Delete post';

  @override
  String get postDeleteMessage => 'This post will be removed for everyone.';

  @override
  String get postDeleteTitle => 'Delete this post?';

  @override
  String get postDeleted => 'Post deleted.';

  @override
  String get postDiscard => 'Discard';

  @override
  String get postDiscardMessage => 'Your photos and caption will be lost.';

  @override
  String get postDiscardTitle => 'Discard this post?';

  @override
  String get postEditTitle => 'Edit post';

  @override
  String get postEdited => 'edited';

  @override
  String get postEmptyError => 'Add a photo or a caption.';

  @override
  String get postFirstComment => 'Be the first to comment!';

  @override
  String get postLike => 'Like';

  @override
  String postLikes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
    );
    return '$_temp0';
  }

  @override
  String get postNewTitle => 'New post';

  @override
  String postPlayedOn(String date) {
    return 'Played on $date';
  }

  @override
  String get postPosted => 'Posted!';

  @override
  String get postPublish => 'Post';

  @override
  String get postRemovePhoto => 'Remove photo';

  @override
  String get postRemoved => 'This post has been removed.';

  @override
  String get postSave => 'Save';

  @override
  String get postTagFriends => 'Tag friends';

  @override
  String get postTagGame => 'Tag a game';

  @override
  String postTaggedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends tagged',
      one: '1 friend tagged',
    );
    return '$_temp0';
  }

  @override
  String get postTakePhoto => 'Take a photo';

  @override
  String get postTitle => 'Post';

  @override
  String get postUnlike => 'Unlike';

  @override
  String get postUnsave => 'Remove from saved';

  @override
  String get postUpdated => 'Post updated.';

  @override
  String postUploading(int current, int total) {
    return 'Uploading $current/$total images…';
  }

  @override
  String postViewComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View $count comments',
      one: 'View 1 comment',
    );
    return '$_temp0';
  }

  @override
  String get postWith => 'With:';

  @override
  String get prefBggImportCompleted => 'BGG import finished';

  @override
  String get prefCommentMention => 'Comment mentions';

  @override
  String get prefEventCancelled => 'Event cancelled';

  @override
  String get prefEventCompleted => 'Event ended';

  @override
  String get prefEventInvite => 'Event invites';

  @override
  String get prefEventKicked => 'Removed from event';

  @override
  String get prefEventLeave => 'Someone left your event';

  @override
  String get prefEventReminder => 'Event reminders';

  @override
  String get prefEventRsvp => 'Event RSVPs';

  @override
  String get prefEventUpdated => 'Event updates';

  @override
  String get prefFriendAccepted => 'Friend request accepted';

  @override
  String get prefFriendRequest => 'Friend requests';

  @override
  String get prefInApp => 'In-App';

  @override
  String get prefMatchAccepted => 'Match accepted';

  @override
  String get prefMatchFound => 'Match found';

  @override
  String get prefPostComment => 'Post comments';

  @override
  String get prefPostLike => 'Post liked';

  @override
  String get prefPostTag => 'Tagged in a post';

  @override
  String get prefPush => 'Push';

  @override
  String get prefRuleNoteApproved => 'Rule note approved';

  @override
  String get prefRuleNoteRejected => 'Rule note rejected';

  @override
  String get prefRulebookApproved => 'Rulebook approved';

  @override
  String get prefRulebookRejected => 'Rulebook rejected';

  @override
  String get prefRulebookUnderReview => 'Rulebook under review';

  @override
  String get prefTypeHeader => 'Notification';

  @override
  String get profileBio => 'Bio';

  @override
  String get profileBlock => 'Block';

  @override
  String get profileBlockMessage =>
      'You\'ll no longer be friends and won\'t see each other\'s content.';

  @override
  String get profileBlockTitle => 'Block this user?';

  @override
  String get profileBlocked => 'User blocked.';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileDisplayNameTooShort => 'Must be at least 2 characters';

  @override
  String get profileEdit => 'Edit Profile';

  @override
  String get profileEmailNote =>
      'To change your email, go to Settings › Change Email.';

  @override
  String get profileFavoriteGames => 'Favorite Games';

  @override
  String get profileLocationHint => 'City, Country';

  @override
  String get profileNoFavorites => 'No favorites yet. Star a game you love.';

  @override
  String get profileNoPosts => 'No posts yet.';

  @override
  String get profileReport => 'Report';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileShare => 'Share profile';

  @override
  String get profileTabCollection => 'Collection';

  @override
  String get profileTabPosts => 'Posts';

  @override
  String get profileTabTagged => 'Tagged';

  @override
  String get profileTaggedBody =>
      'Posts this player was tagged in will appear here once the server supports listing them.';

  @override
  String get profileTaggedTitle => 'Tagged posts';

  @override
  String get profileUnavailable => 'This profile isn\'t available.';

  @override
  String get profileUsername => 'Username';

  @override
  String profileUsernameChangeIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Can change in $days days',
      one: 'Can change in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get profileUsernameInvalid =>
      '3–20 lowercase letters, numbers or underscores';

  @override
  String get profileVerified => 'Verified';

  @override
  String get quietHoursBody =>
      'Push notifications are paused during quiet hours.';

  @override
  String quietHoursFrom(String time) {
    return 'From $time';
  }

  @override
  String get quietHoursTitle => 'Do Not Disturb';

  @override
  String quietHoursTo(String time) {
    return 'To $time';
  }

  @override
  String get reactivateBody =>
      'This account is scheduled for deletion. Log in again within 30 days of deleting it to restore everything.';

  @override
  String get reactivateDone => 'Welcome back! Your account has been restored.';

  @override
  String get reactivateSubmit => 'Reactivate my account';

  @override
  String get reactivateTitle => 'Reactivate your account?';

  @override
  String get reportComment => 'Report comment';

  @override
  String get reportPost => 'Report post';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportSent => 'Thanks — we\'ll review your report.';

  @override
  String get reportTitle => 'Why are you reporting this?';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchEmptyPrompt => 'Search for games, players, or events';

  @override
  String get searchEvents => 'Events';

  @override
  String get searchGames => 'Games';

  @override
  String get searchHint => 'Search Meeple';

  @override
  String searchNoResults(String query) {
    return 'No results for \'$query\'';
  }

  @override
  String get searchPlayers => 'Players';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String sessionsLastActive(String time) {
    return 'Last active $time';
  }

  @override
  String get sessionsRevokeOthers => 'Sign Out All Other Devices';

  @override
  String get sessionsSignOut => 'Sign Out';

  @override
  String get sessionsThisDevice => 'This device';

  @override
  String get sessionsUnknownDevice => 'Unknown device';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsBggImport => 'BGG Import';

  @override
  String get settingsBiometric => 'Biometric lock';

  @override
  String get settingsBiometricBody =>
      'Require Face ID, fingerprint or your device PIN to open Meeple.';

  @override
  String get settingsBiometricUnavailable =>
      'Biometric authentication isn\'t available on this device.';

  @override
  String get settingsCacheCleared => 'Offline cache cleared.';

  @override
  String get settingsChangeEmail => 'Change Email';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsEditProfile => 'Edit Profile';

  @override
  String get settingsExport => 'Export my data';

  @override
  String get settingsExportRequested =>
      'We\'ll email you a download link when your export is ready.';

  @override
  String get settingsFeedback => 'Send Feedback';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsPrivacySettings => 'Privacy Settings';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSessions => 'Active Sessions';

  @override
  String get settingsSignOut => 'Log out';

  @override
  String get settingsSignOutMessage =>
      'You\'ll need to log in again on this device.';

  @override
  String get settingsSignOutTitle => 'Log out?';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsVersion => 'App Version';

  @override
  String get statFriends => 'Friends';

  @override
  String get statGamesOwned => 'Games Owned';

  @override
  String statMostPlayed(String game, int count) {
    return 'Most played: $game ($count)';
  }

  @override
  String get statSessions => 'Sessions';

  @override
  String get visibilityFriends => 'Friends';

  @override
  String get visibilityFriendsHint => 'All your friends can see and join.';

  @override
  String get visibilityInviteOnly => 'Invite only';

  @override
  String get visibilityInviteOnlyHint => 'Only people you invite can see it.';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilityPublicHint =>
      'Anyone in the community can find and join.';

  @override
  String get welcomeEvents => 'Organize game nights with friends';

  @override
  String get welcomeLibrary => 'Track the games you own and love';

  @override
  String get welcomeMatching => 'Get matched with friends who want to play';

  @override
  String get welcomeStart => 'Get Started';

  @override
  String get welcomeTagline =>
      'Track your games. Organize game nights. Build memories.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authYourEmail => 'your email';

  @override
  String get errorFileTooLarge => 'Images must be 10 MB or smaller.';

  @override
  String get errorUnsupportedImage =>
      'Only JPEG, PNG, WebP and GIF images are allowed.';

  @override
  String get errorEmailNotVerified =>
      'Please verify your email address before logging in.';

  @override
  String get errorCannotInviteSelf => 'You can\'t invite yourself.';

  @override
  String get errorBggImportInProgress => 'An import is already running.';
}
