import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Meeple'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonOops.
  ///
  /// In en, this message translates to:
  /// **'Oops!'**
  String get commonOops;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get commonReadMore;

  /// No description provided for @commonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get commonShowLess;

  /// No description provided for @commonDeletedUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted User'**
  String get commonDeletedUser;

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more…'**
  String get loadingMore;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get allCaughtUp;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBanner;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @staleData.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data from {age}'**
  String staleData(String age);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Try again when you reconnect.'**
  String get errorOffline;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t exist or was removed.'**
  String get errorNotFound;

  /// No description provided for @errorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please slow down and try again.'**
  String get errorRateLimit;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This service is temporarily unavailable. Please try again later.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorEditWindowExpired.
  ///
  /// In en, this message translates to:
  /// **'This can no longer be edited.'**
  String get errorEditWindowExpired;

  /// No description provided for @errorEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'This event has been cancelled.'**
  String get errorEventCancelled;

  /// No description provided for @errorEventCompleted.
  ///
  /// In en, this message translates to:
  /// **'This event has already ended.'**
  String get errorEventCompleted;

  /// No description provided for @errorEventFull.
  ///
  /// In en, this message translates to:
  /// **'This event is full.'**
  String get errorEventFull;

  /// No description provided for @errorNotHost.
  ///
  /// In en, this message translates to:
  /// **'Only the host can do that.'**
  String get errorNotHost;

  /// No description provided for @errorNotFriends.
  ///
  /// In en, this message translates to:
  /// **'You can only do that with friends.'**
  String get errorNotFriends;

  /// No description provided for @errorRequestCooldown.
  ///
  /// In en, this message translates to:
  /// **'Please wait before sending another friend request.'**
  String get errorRequestCooldown;

  /// No description provided for @errorPendingLimit.
  ///
  /// In en, this message translates to:
  /// **'You have too many pending friend requests.'**
  String get errorPendingLimit;

  /// No description provided for @errorReportLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s report limit.'**
  String get errorReportLimit;

  /// No description provided for @errorBggUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'BGG username not found. Check the spelling.'**
  String get errorBggUserNotFound;

  /// No description provided for @errorBggUnavailable.
  ///
  /// In en, this message translates to:
  /// **'BGG is currently slow. Skip for now and try again later.'**
  String get errorBggUnavailable;

  /// No description provided for @errorUsernameTooSoon.
  ///
  /// In en, this message translates to:
  /// **'You can only change your username once every 30 days.'**
  String get errorUsernameTooSoon;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get errorUsernameTaken;

  /// No description provided for @errorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get errorEmailTaken;

  /// No description provided for @errorAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'This account is scheduled for deletion.'**
  String get errorAccountDeleted;

  /// No description provided for @errorGoogleEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your Google email address is not verified.'**
  String get errorGoogleEmailNotVerified;

  /// No description provided for @errorGoogleAccountConflict.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered with a password. Sign in with your password instead.'**
  String get errorGoogleAccountConflict;

  /// No description provided for @errorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get errorGoogleFailed;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @aiRateLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the 20 questions/day limit. Resets at midnight UTC.'**
  String get aiRateLimit;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createTitle;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Post a game night'**
  String get createPost;

  /// No description provided for @createEvent.
  ///
  /// In en, this message translates to:
  /// **'Host an event'**
  String get createEvent;

  /// No description provided for @createAddGame.
  ///
  /// In en, this message translates to:
  /// **'Add a game'**
  String get createAddGame;

  /// No description provided for @createFindMatch.
  ///
  /// In en, this message translates to:
  /// **'Find players'**
  String get createFindMatch;

  /// No description provided for @pushPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop about your game nights'**
  String get pushPromptTitle;

  /// No description provided for @pushPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified about invites, reminders, friend requests and new comments.'**
  String get pushPromptBody;

  /// No description provided for @pushPromptAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications'**
  String get pushPromptAllow;

  /// No description provided for @pushPromptNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pushPromptNotNow;

  /// No description provided for @pushChannelEvents.
  ///
  /// In en, this message translates to:
  /// **'Events & Game Nights'**
  String get pushChannelEvents;

  /// No description provided for @pushChannelEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Invites, reminders, and match notifications'**
  String get pushChannelEventsDescription;

  /// No description provided for @pushChannelSocial.
  ///
  /// In en, this message translates to:
  /// **'Social Activity'**
  String get pushChannelSocial;

  /// No description provided for @pushChannelSocialDescription.
  ///
  /// In en, this message translates to:
  /// **'Likes, comments, and friend requests'**
  String get pushChannelSocialDescription;

  /// No description provided for @appLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeple is locked'**
  String get appLockedTitle;

  /// No description provided for @appLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics or your device passcode.'**
  String get appLockedBody;

  /// No description provided for @appLockedUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockedUnlock;

  /// No description provided for @biometricReasonUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock Meeple'**
  String get biometricReasonUnlock;

  /// No description provided for @biometricReasonEnable.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to enable the app lock'**
  String get biometricReasonEnable;

  /// No description provided for @activityCollectionAdd.
  ///
  /// In en, this message translates to:
  /// **'{name} added {game} to their collection.'**
  String activityCollectionAdd(String name, String game);

  /// No description provided for @activityEventCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} is hosting {event}.'**
  String activityEventCreated(String name, String event);

  /// No description provided for @activityEventJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined {event}.'**
  String activityEventJoined(String name, String event);

  /// No description provided for @activityGeneric.
  ///
  /// In en, this message translates to:
  /// **'{name} has new activity'**
  String activityGeneric(String name);

  /// No description provided for @aiAskAnyway.
  ///
  /// In en, this message translates to:
  /// **'Ask anyway'**
  String get aiAskAnyway;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated answers may not be 100% accurate.'**
  String get aiDisclaimer;

  /// No description provided for @aiError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get aiError;

  /// No description provided for @aiInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question...'**
  String get aiInputHint;

  /// No description provided for @aiNoRulebook.
  ///
  /// In en, this message translates to:
  /// **'No rulebook available for {game} yet.'**
  String aiNoRulebook(String game);

  /// No description provided for @aiNoRulebookBody.
  ///
  /// In en, this message translates to:
  /// **'Answers will be based on general knowledge and may be less accurate.'**
  String get aiNoRulebookBody;

  /// No description provided for @aiNoRulebookTooltip.
  ///
  /// In en, this message translates to:
  /// **'No rulebook uploaded yet'**
  String get aiNoRulebookTooltip;

  /// No description provided for @aiPromptSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup instructions'**
  String get aiPromptSetup;

  /// No description provided for @aiPromptTurn.
  ///
  /// In en, this message translates to:
  /// **'What happens on your turn?'**
  String get aiPromptTurn;

  /// No description provided for @aiPromptWin.
  ///
  /// In en, this message translates to:
  /// **'How do you win?'**
  String get aiPromptWin;

  /// No description provided for @aiRulesAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Rules Assistant'**
  String get aiRulesAssistant;

  /// No description provided for @aiSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{game} Rules Assistant'**
  String aiSheetTitle(String game);

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get authBackToSignIn;

  /// No description provided for @authCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get authCheckInbox;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authConfirmNewPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccountTitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get authEmailHint;

  /// No description provided for @authEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get authEmailOrUsername;

  /// No description provided for @authEmailOrUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email or username'**
  String get authEmailOrUsernameRequired;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authForgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you registered with and we\'ll send you a reset link.'**
  String get authForgotBody;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authForgotTitle;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authIveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Verified My Email'**
  String get authIveVerified;

  /// No description provided for @authJoin.
  ///
  /// In en, this message translates to:
  /// **'Join the Meeple community'**
  String get authJoin;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Your new password must be at least 8 characters.'**
  String get authNewPasswordHint;

  /// No description provided for @authNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPasswordTitle;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Must be 8–128 characters'**
  String get authPasswordLength;

  /// No description provided for @authPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters'**
  String get authPasswordMin;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated!'**
  String get authPasswordUpdated;

  /// No description provided for @authPasswordUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset. Sign in with your new password.'**
  String get authPasswordUpdatedBody;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authPasswordsMismatch;

  /// No description provided for @authResendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get authResendEmail;

  /// No description provided for @authResetLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired. Request a new one.'**
  String get authResetLinkExpired;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetSentTo.
  ///
  /// In en, this message translates to:
  /// **'If {email} is registered, you\'ll receive a reset link.'**
  String authResetSentTo(String email);

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get authSendResetLink;

  /// No description provided for @authSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get authSetNewPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authSignIn;

  /// No description provided for @authSignInLink.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authSignInLink;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUp;

  /// No description provided for @authTermsNote.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to our Terms of Service and Privacy Policy.'**
  String get authTermsNote;

  /// No description provided for @authUsernameLength.
  ///
  /// In en, this message translates to:
  /// **'3–20 lowercase letters, numbers or underscores'**
  String get authUsernameLength;

  /// No description provided for @authUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get authUsernameRequired;

  /// No description provided for @authVerificationResent.
  ///
  /// In en, this message translates to:
  /// **'Email resent!'**
  String get authVerificationResent;

  /// No description provided for @authVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Click the link in the email to activate your account.'**
  String get authVerifyBody;

  /// No description provided for @authVerifyFirst.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get authVerifyFirst;

  /// No description provided for @authVerifySentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}'**
  String authVerifySentTo(String email);

  /// No description provided for @avatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get avatarChange;

  /// No description provided for @avatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop Photo'**
  String get avatarCropTitle;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Try again.'**
  String get avatarUploadFailed;

  /// No description provided for @badgeFavorited.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get badgeFavorited;

  /// No description provided for @badgeOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get badgeOwned;

  /// No description provided for @badgeWishlisted.
  ///
  /// In en, this message translates to:
  /// **'On wishlist'**
  String get badgeWishlisted;

  /// No description provided for @bggImportBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your BoardGameGeek username to import your collection.'**
  String get bggImportBody;

  /// No description provided for @bggImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} games ({skipped} skipped, {failed} failed).'**
  String bggImportDone(int imported, int skipped, int failed);

  /// No description provided for @bggImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed. Please try again.'**
  String get bggImportFailed;

  /// No description provided for @bggImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing… {processed} of {total} games'**
  String bggImportProgress(int processed, int total);

  /// No description provided for @bggImportStart.
  ///
  /// In en, this message translates to:
  /// **'Import Collection'**
  String get bggImportStart;

  /// No description provided for @bggImportStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting import…'**
  String get bggImportStarting;

  /// No description provided for @bggImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import your collection'**
  String get bggImportTitle;

  /// No description provided for @bggPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We only read your public collection.'**
  String get bggPrivacyNote;

  /// No description provided for @bggUsername.
  ///
  /// In en, this message translates to:
  /// **'BGG username'**
  String get bggUsername;

  /// No description provided for @blockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get blockedEmpty;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedTitle;

  /// No description provided for @bookmarksEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on a post to save it here.'**
  String get bookmarksEmptyBody;

  /// No description provided for @bookmarksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet'**
  String get bookmarksEmptyTitle;

  /// No description provided for @bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get bookmarksTitle;

  /// No description provided for @changeEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification link to your new address. Your email changes once you confirm it.'**
  String get changeEmailBody;

  /// No description provided for @changeEmailCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changeEmailCurrentPassword;

  /// No description provided for @changeEmailNew.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get changeEmailNew;

  /// No description provided for @changeEmailSentBody.
  ///
  /// In en, this message translates to:
  /// **'Open the link we sent to {email} to confirm the change.'**
  String changeEmailSentBody(String email);

  /// No description provided for @changeEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your new inbox'**
  String get changeEmailSentTitle;

  /// No description provided for @changeEmailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send verification link'**
  String get changeEmailSubmit;

  /// No description provided for @changePasswordBody.
  ///
  /// In en, this message translates to:
  /// **'For your security, password changes go through email. We\'ll send a reset link to {email}.'**
  String changePasswordBody(String email);

  /// No description provided for @changePasswordNoEmail.
  ///
  /// In en, this message translates to:
  /// **'Request a reset link with the email you registered with.'**
  String get changePasswordNoEmail;

  /// No description provided for @changePasswordSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get changePasswordSend;

  /// No description provided for @changePasswordSentBody.
  ///
  /// In en, this message translates to:
  /// **'Follow the link in the email to choose a new password.'**
  String get changePasswordSentBody;

  /// No description provided for @changePasswordSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent'**
  String get changePasswordSentTitle;

  /// No description provided for @collectionNoPlays.
  ///
  /// In en, this message translates to:
  /// **'No plays logged yet.'**
  String get collectionNoPlays;

  /// No description provided for @collectionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get collectionNotes;

  /// No description provided for @collectionPlayHistory.
  ///
  /// In en, this message translates to:
  /// **'Play history'**
  String get collectionPlayHistory;

  /// No description provided for @collectionRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating: {rating}'**
  String collectionRating(String rating);

  /// No description provided for @collectionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get collectionRemove;

  /// No description provided for @collectionRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'{game} will be removed from your collection, wishlist and favorites.'**
  String collectionRemoveMessage(String game);

  /// No description provided for @collectionRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this game?'**
  String get collectionRemoveTitle;

  /// No description provided for @commentDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This comment will be removed.'**
  String get commentDeleteMessage;

  /// No description provided for @commentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get commentDeleteTitle;

  /// No description provided for @commentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentEditTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete your account. You have 30 days to reactivate it by logging in again.'**
  String get deleteConfirmMessage;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion.'**
  String get deleteDone;

  /// No description provided for @deletePasswordless.
  ///
  /// In en, this message translates to:
  /// **'I signed up with Google (no password)'**
  String get deletePasswordless;

  /// No description provided for @deleteSubmit.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteSubmit;

  /// No description provided for @deleteTypeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteTypeConfirm;

  /// No description provided for @deleteTypeConfirmError.
  ///
  /// In en, this message translates to:
  /// **'Please type DELETE'**
  String get deleteTypeConfirmError;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deactivated immediately and permanently deleted after 30 days. Your collection, friendships, match requests and notifications are removed now; posts and comments show as \"Deleted User\". Log in within 30 days to reactivate.'**
  String get deleteWarning;

  /// No description provided for @eventAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get eventAccept;

  /// No description provided for @eventCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel event'**
  String get eventCancelConfirm;

  /// No description provided for @eventCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Everyone who joined or was invited will be notified.'**
  String get eventCancelMessage;

  /// No description provided for @eventCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this event?'**
  String get eventCancelTitle;

  /// No description provided for @eventCancelledBanner.
  ///
  /// In en, this message translates to:
  /// **'This event has been cancelled.'**
  String get eventCancelledBanner;

  /// No description provided for @eventChangeToGoing.
  ///
  /// In en, this message translates to:
  /// **'Change to Going'**
  String get eventChangeToGoing;

  /// No description provided for @eventChooseFriends.
  ///
  /// In en, this message translates to:
  /// **'Choose friends'**
  String get eventChooseFriends;

  /// No description provided for @eventCreated.
  ///
  /// In en, this message translates to:
  /// **'Event created!'**
  String get eventCreated;

  /// No description provided for @eventCreatedInvites.
  ///
  /// In en, this message translates to:
  /// **'Event created! Invites sent.'**
  String get eventCreatedInvites;

  /// No description provided for @eventDateInPast.
  ///
  /// In en, this message translates to:
  /// **'Please choose a future date.'**
  String get eventDateInPast;

  /// No description provided for @eventDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please pick a date and time.'**
  String get eventDateRequired;

  /// No description provided for @eventDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get eventDecline;

  /// No description provided for @eventDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'{game} Night'**
  String eventDefaultTitle(String game);

  /// No description provided for @eventEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEdit;

  /// No description provided for @eventEndedBanner.
  ///
  /// In en, this message translates to:
  /// **'This event has ended.'**
  String get eventEndedBanner;

  /// No description provided for @eventFieldDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get eventFieldDateTime;

  /// No description provided for @eventFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get eventFieldDescription;

  /// No description provided for @eventFieldGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get eventFieldGame;

  /// No description provided for @eventFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventFieldLocation;

  /// No description provided for @eventFieldMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Max players'**
  String get eventFieldMaxPlayers;

  /// No description provided for @eventFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventFieldTitle;

  /// No description provided for @eventFieldVisibility.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get eventFieldVisibility;

  /// No description provided for @eventFull.
  ///
  /// In en, this message translates to:
  /// **'Event is Full'**
  String get eventFull;

  /// No description provided for @eventGoingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 going} other{{count} going}}'**
  String eventGoingCount(int count);

  /// No description provided for @eventHostedBy.
  ///
  /// In en, this message translates to:
  /// **'Hosted by {name}'**
  String eventHostedBy(String name);

  /// No description provided for @eventInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get eventInviteFriends;

  /// No description provided for @eventInvitedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} invited'**
  String eventInvitedCount(int count);

  /// No description provided for @eventInvitesSent.
  ///
  /// In en, this message translates to:
  /// **'Invites sent.'**
  String get eventInvitesSent;

  /// No description provided for @eventJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get eventJoin;

  /// No description provided for @eventJoined.
  ///
  /// In en, this message translates to:
  /// **'You\'re going!'**
  String get eventJoined;

  /// No description provided for @eventKick.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get eventKick;

  /// No description provided for @eventKickMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from this event.'**
  String eventKickMessage(String name);

  /// No description provided for @eventKickTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove participant?'**
  String get eventKickTitle;

  /// No description provided for @eventLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Event'**
  String get eventLeave;

  /// No description provided for @eventLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Your spot will open up for someone else.'**
  String get eventLeaveMessage;

  /// No description provided for @eventLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this event?'**
  String get eventLeaveTitle;

  /// No description provided for @eventLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Address, venue name, or \'Online\''**
  String get eventLocationHint;

  /// No description provided for @eventManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Event'**
  String get eventManage;

  /// No description provided for @eventNoMemories.
  ///
  /// In en, this message translates to:
  /// **'No memories shared yet.'**
  String get eventNoMemories;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'This event doesn\'t exist or was removed.'**
  String get eventNotFound;

  /// No description provided for @eventPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get eventPickDate;

  /// No description provided for @eventPickGame.
  ///
  /// In en, this message translates to:
  /// **'Search for a game'**
  String get eventPickGame;

  /// No description provided for @eventPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get eventPickTime;

  /// No description provided for @eventPlayersCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} players'**
  String eventPlayersCount(int count, int max);

  /// No description provided for @eventRemoveGame.
  ///
  /// In en, this message translates to:
  /// **'Remove game'**
  String get eventRemoveGame;

  /// No description provided for @eventStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get eventStatusCancelled;

  /// No description provided for @eventStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get eventStatusCompleted;

  /// No description provided for @eventStatusFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get eventStatusFull;

  /// No description provided for @eventStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get eventStatusOpen;

  /// No description provided for @eventTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 3 characters'**
  String get eventTitleTooShort;

  /// No description provided for @eventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event updated.'**
  String get eventUpdated;

  /// No description provided for @eventViewMemories.
  ///
  /// In en, this message translates to:
  /// **'View Memories'**
  String get eventViewMemories;

  /// No description provided for @eventYouWereRemoved.
  ///
  /// In en, this message translates to:
  /// **'The host removed you from this event.'**
  String get eventYouWereRemoved;

  /// No description provided for @eventsCalendarView.
  ///
  /// In en, this message translates to:
  /// **'Calendar view'**
  String get eventsCalendarView;

  /// No description provided for @eventsEmptyPastBody.
  ///
  /// In en, this message translates to:
  /// **'Your game night history will appear here.'**
  String get eventsEmptyPastBody;

  /// No description provided for @eventsEmptyPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past events.'**
  String get eventsEmptyPastTitle;

  /// No description provided for @eventsEmptyUpcomingBody.
  ///
  /// In en, this message translates to:
  /// **'Host your next game night!'**
  String get eventsEmptyUpcomingBody;

  /// No description provided for @eventsEmptyUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events.'**
  String get eventsEmptyUpcomingTitle;

  /// No description provided for @eventsListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get eventsListView;

  /// No description provided for @eventsNoneThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No events this month.'**
  String get eventsNoneThisMonth;

  /// No description provided for @eventsTabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get eventsTabMine;

  /// No description provided for @eventsTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get eventsTabPast;

  /// No description provided for @eventsTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get eventsTabUpcoming;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventsTitle;

  /// No description provided for @filter1to2h.
  ///
  /// In en, this message translates to:
  /// **'1–2h'**
  String get filter1to2h;

  /// No description provided for @filter30to60.
  ///
  /// In en, this message translates to:
  /// **'30–60m'**
  String get filter30to60;

  /// No description provided for @filterHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get filterHeavy;

  /// No description provided for @filterLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get filterLight;

  /// No description provided for @filterMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get filterMedium;

  /// No description provided for @filterOver2h.
  ///
  /// In en, this message translates to:
  /// **'2h+'**
  String get filterOver2h;

  /// No description provided for @filterPlayers.
  ///
  /// In en, this message translates to:
  /// **'{count}+ players'**
  String filterPlayers(int count);

  /// No description provided for @filterUnder30.
  ///
  /// In en, this message translates to:
  /// **'< 30m'**
  String get filterUnder30;

  /// No description provided for @friendAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendAccept;

  /// No description provided for @friendAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get friendAdd;

  /// No description provided for @friendCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Your friend request will be withdrawn.'**
  String get friendCancelMessage;

  /// No description provided for @friendCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get friendCancelRequest;

  /// No description provided for @friendCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel friend request?'**
  String get friendCancelTitle;

  /// No description provided for @friendDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendDecline;

  /// No description provided for @friendFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendFriends;

  /// No description provided for @friendPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendPending;

  /// No description provided for @friendPickerDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Done} other{Done ({count})}}'**
  String friendPickerDone(int count);

  /// No description provided for @friendPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends to show.'**
  String get friendPickerEmpty;

  /// No description provided for @friendPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get friendPickerSearch;

  /// No description provided for @friendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent.'**
  String get friendRequestSent;

  /// No description provided for @friendUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get friendUnblock;

  /// No description provided for @friendUnfriend.
  ///
  /// In en, this message translates to:
  /// **'Unfriend'**
  String get friendUnfriend;

  /// No description provided for @friendUnfriendMessage.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see each other\'s friends-only content.'**
  String get friendUnfriendMessage;

  /// No description provided for @friendUnfriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove friend?'**
  String get friendUnfriendTitle;

  /// No description provided for @friendsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find people you play with and add them as friends.'**
  String get friendsEmptyBody;

  /// No description provided for @friendsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsEmptyTitle;

  /// No description provided for @friendsNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending friend requests.'**
  String get friendsNoRequests;

  /// No description provided for @friendsNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet. Search for friends by username.'**
  String get friendsNoSuggestions;

  /// No description provided for @friendsReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get friendsReceived;

  /// No description provided for @friendsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get friendsSearchHint;

  /// No description provided for @friendsSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get friendsSent;

  /// No description provided for @friendsSuggestions.
  ///
  /// In en, this message translates to:
  /// **'People you may know'**
  String get friendsSuggestions;

  /// No description provided for @friendsTabFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get friendsTabFind;

  /// No description provided for @friendsTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTabFriends;

  /// No description provided for @friendsTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get friendsTabRequests;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @gameAddToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to Collection'**
  String get gameAddToCollection;

  /// No description provided for @gameAddedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Added to collection!'**
  String get gameAddedToCollection;

  /// No description provided for @gameBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to Library'**
  String get gameBackToLibrary;

  /// No description provided for @gameBggRating.
  ///
  /// In en, this message translates to:
  /// **'BGG rating {rating}'**
  String gameBggRating(String rating);

  /// No description provided for @gameCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get gameCategories;

  /// No description provided for @gameFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get gameFavorite;

  /// No description provided for @gameFriendRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} avg from {count, plural, =1{1 friend} other{{count} friends}}'**
  String gameFriendRating(String rating, int count);

  /// No description provided for @gameInCollection.
  ///
  /// In en, this message translates to:
  /// **'In Collection'**
  String get gameInCollection;

  /// No description provided for @gameInfoComplexity.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get gameInfoComplexity;

  /// No description provided for @gameInfoDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get gameInfoDuration;

  /// No description provided for @gameInfoPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get gameInfoPlayers;

  /// No description provided for @gameLogPlay.
  ///
  /// In en, this message translates to:
  /// **'Log a play'**
  String get gameLogPlay;

  /// No description provided for @gameMechanics.
  ///
  /// In en, this message translates to:
  /// **'Mechanics'**
  String get gameMechanics;

  /// No description provided for @gameMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String gameMinutes(int minutes);

  /// No description provided for @gameNoFriendsOwn.
  ///
  /// In en, this message translates to:
  /// **'None of your friends own this yet.'**
  String get gameNoFriendsOwn;

  /// No description provided for @gameNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews from friends yet.'**
  String get gameNoReviews;

  /// No description provided for @gameNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions logged yet.'**
  String get gameNoSessions;

  /// No description provided for @gameNotFound.
  ///
  /// In en, this message translates to:
  /// **'This game doesn\'t exist or was removed.'**
  String get gameNotFound;

  /// No description provided for @gameOnWishlist.
  ///
  /// In en, this message translates to:
  /// **'On Wishlist'**
  String get gameOnWishlist;

  /// No description provided for @gameOwnedByFriends.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Owned by 1 friend} other{Owned by {count} friends}}'**
  String gameOwnedByFriends(int count);

  /// No description provided for @gamePlayers.
  ///
  /// In en, this message translates to:
  /// **'{range} players'**
  String gamePlayers(String range);

  /// No description provided for @gamePlays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String gamePlays(int count);

  /// No description provided for @gameTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get gameTabFriends;

  /// No description provided for @gameTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get gameTabOverview;

  /// No description provided for @gameTabReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get gameTabReviews;

  /// No description provided for @gameTabSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get gameTabSessions;

  /// No description provided for @gameUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get gameUnfavorite;

  /// No description provided for @gameWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get gameWishlist;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}!'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}!'**
  String greetingEvening(String name);

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}!'**
  String greetingMorning(String name);

  /// No description provided for @greetingNextSession.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Your next session is today.} =1{Your next session is tomorrow.} other{Your next session is in {days} days.}}'**
  String greetingNextSession(int days);

  /// No description provided for @greetingNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events.'**
  String get greetingNoEvents;

  /// No description provided for @homeCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create a Post'**
  String get homeCreatePost;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your friends haven\'t posted recently.'**
  String get homeEmptyBody;

  /// No description provided for @homeEmptyNoFriendsBody.
  ///
  /// In en, this message translates to:
  /// **'Add friends to see what they\'re playing.'**
  String get homeEmptyNoFriendsBody;

  /// No description provided for @homeEmptyNoFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your feed is quiet.'**
  String get homeEmptyNoFriendsTitle;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing new yet.'**
  String get homeEmptyTitle;

  /// No description provided for @homeFeedError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your feed.'**
  String get homeFeedError;

  /// No description provided for @homeFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeFeedTitle;

  /// No description provided for @homeFindFriends.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get homeFindFriends;

  /// No description provided for @homeMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Match suggestions'**
  String get homeMatchesTitle;

  /// No description provided for @homeMoreMatches.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String homeMoreMatches(int count);

  /// No description provided for @homeUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get homeUpcomingTitle;

  /// No description provided for @homeViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'View Calendar'**
  String get homeViewCalendar;

  /// No description provided for @htpActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get htpActions;

  /// No description provided for @htpEnd.
  ///
  /// In en, this message translates to:
  /// **'End of game'**
  String get htpEnd;

  /// No description provided for @htpFailed.
  ///
  /// In en, this message translates to:
  /// **'The guide could not be generated.'**
  String get htpFailed;

  /// No description provided for @htpFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get htpFaq;

  /// No description provided for @htpGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate guide'**
  String get htpGenerate;

  /// No description provided for @htpGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating… {progress}%'**
  String htpGenerating(int progress);

  /// No description provided for @htpNotGenerated.
  ///
  /// In en, this message translates to:
  /// **'No How to Play guide yet.'**
  String get htpNotGenerated;

  /// No description provided for @htpObjective.
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get htpObjective;

  /// No description provided for @htpOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get htpOverview;

  /// No description provided for @htpResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get htpResources;

  /// No description provided for @htpRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get htpRules;

  /// No description provided for @htpScoring.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get htpScoring;

  /// No description provided for @htpSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get htpSetup;

  /// No description provided for @htpTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get htpTips;

  /// No description provided for @htpTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Play'**
  String get htpTitle;

  /// No description provided for @htpTurns.
  ///
  /// In en, this message translates to:
  /// **'Turns'**
  String get htpTurns;

  /// No description provided for @htpUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The guide is unavailable right now.'**
  String get htpUnavailable;

  /// No description provided for @htpWinning.
  ///
  /// In en, this message translates to:
  /// **'Winning'**
  String get htpWinning;

  /// No description provided for @libraryBrowseGames.
  ///
  /// In en, this message translates to:
  /// **'Browse Games'**
  String get libraryBrowseGames;

  /// No description provided for @libraryDatabaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Game database unavailable.'**
  String get libraryDatabaseUnavailable;

  /// No description provided for @libraryEmptyCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'Search for games to add to your collection.'**
  String get libraryEmptyCollectionBody;

  /// No description provided for @libraryEmptyCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your shelf is empty.'**
  String get libraryEmptyCollectionTitle;

  /// No description provided for @libraryEmptyFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Favorite a game you love.'**
  String get libraryEmptyFavoritesBody;

  /// No description provided for @libraryEmptyFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.'**
  String get libraryEmptyFavoritesTitle;

  /// No description provided for @libraryEmptyWishlistBody.
  ///
  /// In en, this message translates to:
  /// **'Browse the library and add games you want.'**
  String get libraryEmptyWishlistBody;

  /// No description provided for @libraryEmptyWishlistTitle.
  ///
  /// In en, this message translates to:
  /// **'No games on your wishlist yet.'**
  String get libraryEmptyWishlistTitle;

  /// No description provided for @libraryNoGames.
  ///
  /// In en, this message translates to:
  /// **'No games to show.'**
  String get libraryNoGames;

  /// No description provided for @libraryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No games found for \'{query}\'.'**
  String libraryNoResults(String query);

  /// No description provided for @libraryNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different spelling or fewer filters.'**
  String get libraryNoResultsHint;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search games'**
  String get librarySearchHint;

  /// No description provided for @libraryTabAll.
  ///
  /// In en, this message translates to:
  /// **'All Games'**
  String get libraryTabAll;

  /// No description provided for @libraryTabCollection.
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get libraryTabCollection;

  /// No description provided for @libraryTabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryTabFavorites;

  /// No description provided for @libraryTabWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get libraryTabWishlist;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @matchActiveRequests.
  ///
  /// In en, this message translates to:
  /// **'Active requests'**
  String get matchActiveRequests;

  /// No description provided for @matchAvailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Available from'**
  String get matchAvailableFrom;

  /// No description provided for @matchAvailableRange.
  ///
  /// In en, this message translates to:
  /// **'Available {from} – {to}'**
  String matchAvailableRange(String from, String to);

  /// No description provided for @matchAvailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until'**
  String get matchAvailableUntil;

  /// No description provided for @matchDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get matchDismiss;

  /// No description provided for @matchFormBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll match you with friends who want to play the same game at the same time.'**
  String get matchFormBody;

  /// No description provided for @matchFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Find players'**
  String get matchFormTitle;

  /// No description provided for @matchFriendsWantToPlay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 friend wants to play {game}} other{{count} friends want to play {game}}}'**
  String matchFriendsWantToPlay(int count, String game);

  /// No description provided for @matchFromValue.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String matchFromValue(String time);

  /// No description provided for @matchInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start.'**
  String get matchInvalidRange;

  /// No description provided for @matchNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No active match requests.'**
  String get matchNoRequests;

  /// No description provided for @matchNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No match suggestions right now.'**
  String get matchNoSuggestions;

  /// No description provided for @matchPickGameFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a game first.'**
  String get matchPickGameFirst;

  /// No description provided for @matchRequestCreated.
  ///
  /// In en, this message translates to:
  /// **'Match request created.'**
  String get matchRequestCreated;

  /// No description provided for @matchSubmit.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Play!'**
  String get matchSubmit;

  /// No description provided for @matchUntilValue.
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String matchUntilValue(String time);

  /// No description provided for @matchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get matchingTitle;

  /// No description provided for @minutesSuffix.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesSuffix;

  /// No description provided for @notifBggImportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your BGG import finished: {count} games added.'**
  String notifBggImportCompleted(int count);

  /// No description provided for @notifCommentMention.
  ///
  /// In en, this message translates to:
  /// **'{name} mentioned you in a comment'**
  String notifCommentMention(String name);

  /// No description provided for @notifEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'{event} was cancelled'**
  String notifEventCancelled(String event);

  /// No description provided for @notifEventCompleted.
  ///
  /// In en, this message translates to:
  /// **'{event} has ended. Share your memories!'**
  String notifEventCompleted(String event);

  /// No description provided for @notifEventInvite.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to {event}'**
  String notifEventInvite(String name, String event);

  /// No description provided for @notifEventKicked.
  ///
  /// In en, this message translates to:
  /// **'You were removed from {event}'**
  String notifEventKicked(String event);

  /// No description provided for @notifEventLeave.
  ///
  /// In en, this message translates to:
  /// **'{name} left {event}'**
  String notifEventLeave(String name, String event);

  /// No description provided for @notifEventReminder.
  ///
  /// In en, this message translates to:
  /// **'{event} starts soon'**
  String notifEventReminder(String event);

  /// No description provided for @notifEventRsvp.
  ///
  /// In en, this message translates to:
  /// **'{name} is going to {event}'**
  String notifEventRsvp(String name, String event);

  /// No description provided for @notifEventUpdated.
  ///
  /// In en, this message translates to:
  /// **'{event} was updated'**
  String notifEventUpdated(String event);

  /// No description provided for @notifFriendAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your friend request'**
  String notifFriendAccepted(String name);

  /// No description provided for @notifFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request'**
  String notifFriendRequest(String name);

  /// No description provided for @notifMatchAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted the match for {game}'**
  String notifMatchAccepted(String name, String game);

  /// No description provided for @notifMatchFound.
  ///
  /// In en, this message translates to:
  /// **'New match found for {game}'**
  String notifMatchFound(String game);

  /// No description provided for @notifPostComment.
  ///
  /// In en, this message translates to:
  /// **'{name} commented on your post'**
  String notifPostComment(String name);

  /// No description provided for @notifPostLike.
  ///
  /// In en, this message translates to:
  /// **'{name} liked your post'**
  String notifPostLike(String name);

  /// No description provided for @notifPostTag.
  ///
  /// In en, this message translates to:
  /// **'{name} tagged you in a post'**
  String notifPostTag(String name);

  /// No description provided for @notifRuleNoteApproved.
  ///
  /// In en, this message translates to:
  /// **'Your rule note for {game} was approved'**
  String notifRuleNoteApproved(String game);

  /// No description provided for @notifRuleNoteRejected.
  ///
  /// In en, this message translates to:
  /// **'Your rule note for {game} was rejected'**
  String notifRuleNoteRejected(String game);

  /// No description provided for @notifRulebookApproved.
  ///
  /// In en, this message translates to:
  /// **'The rulebook for {game} was approved'**
  String notifRulebookApproved(String game);

  /// No description provided for @notifRulebookRejected.
  ///
  /// In en, this message translates to:
  /// **'The rulebook for {game} was rejected'**
  String notifRulebookRejected(String game);

  /// No description provided for @notifRulebookUnderReview.
  ///
  /// In en, this message translates to:
  /// **'The rulebook for {game} is under review'**
  String notifRulebookUnderReview(String game);

  /// No description provided for @notificationAGame.
  ///
  /// In en, this message translates to:
  /// **'a game'**
  String get notificationAGame;

  /// No description provided for @notificationAnEvent.
  ///
  /// In en, this message translates to:
  /// **'an event'**
  String get notificationAnEvent;

  /// No description provided for @notificationPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPrefsTitle;

  /// No description provided for @notificationSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationSomeone;

  /// No description provided for @notificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications will appear here.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationsMarkRead;

  /// No description provided for @notificationsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get notificationsThisWeek;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsToday;

  /// No description provided for @onboardingAddGameBody.
  ///
  /// In en, this message translates to:
  /// **'Add a few games you own to get started.'**
  String get onboardingAddGameBody;

  /// No description provided for @onboardingAddGameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add {game} to your collection?'**
  String onboardingAddGameConfirm(String game);

  /// No description provided for @onboardingAddGameTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you love to play?'**
  String get onboardingAddGameTitle;

  /// No description provided for @onboardingBggBody.
  ///
  /// In en, this message translates to:
  /// **'Already on BoardGameGeek? Bring your collection over.'**
  String get onboardingBggBody;

  /// No description provided for @onboardingBggTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from BoardGameGeek'**
  String get onboardingBggTitle;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get onboardingFinish;

  /// No description provided for @onboardingFriendsBody.
  ///
  /// In en, this message translates to:
  /// **'Send friend requests to people you play with.'**
  String get onboardingFriendsBody;

  /// No description provided for @onboardingFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your friends'**
  String get onboardingFriendsTitle;

  /// No description provided for @onboardingPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular games'**
  String get onboardingPopular;

  /// No description provided for @onboardingProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and a name so friends recognise you.'**
  String get onboardingProfileBody;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get onboardingProfileTitle;

  /// No description provided for @playDate.
  ///
  /// In en, this message translates to:
  /// **'Date played'**
  String get playDate;

  /// No description provided for @playDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get playDuration;

  /// No description provided for @playFewerPlayers.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get playFewerPlayers;

  /// No description provided for @playLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a play of {game}'**
  String playLogTitle(String game);

  /// No description provided for @playLogged.
  ///
  /// In en, this message translates to:
  /// **'Play logged!'**
  String get playLogged;

  /// No description provided for @playMorePlayers.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get playMorePlayers;

  /// No description provided for @playNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get playNotes;

  /// No description provided for @playPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get playPlayers;

  /// No description provided for @postAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get postAddComment;

  /// No description provided for @postAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add Photos'**
  String get postAddPhotos;

  /// No description provided for @postCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'What happened at the table?'**
  String get postCaptionHint;

  /// No description provided for @postComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get postComment;

  /// No description provided for @postCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Comments} =1{1 comment} other{{count} comments}}'**
  String postCommentsTitle(int count);

  /// No description provided for @postCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing…'**
  String get postCompressing;

  /// No description provided for @postDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get postDelete;

  /// No description provided for @postDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This post will be removed for everyone.'**
  String get postDeleteMessage;

  /// No description provided for @postDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get postDeleted;

  /// No description provided for @postDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get postDiscard;

  /// No description provided for @postDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your photos and caption will be lost.'**
  String get postDiscardMessage;

  /// No description provided for @postDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this post?'**
  String get postDiscardTitle;

  /// No description provided for @postEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get postEditTitle;

  /// No description provided for @postEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get postEdited;

  /// No description provided for @postEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or a caption.'**
  String get postEmptyError;

  /// No description provided for @postFirstComment.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment!'**
  String get postFirstComment;

  /// No description provided for @postLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get postLike;

  /// No description provided for @postLikes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 like} other{{count} likes}}'**
  String postLikes(int count);

  /// No description provided for @postNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get postNewTitle;

  /// No description provided for @postPlayedOn.
  ///
  /// In en, this message translates to:
  /// **'Played on {date}'**
  String postPlayedOn(String date);

  /// No description provided for @postPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted!'**
  String get postPosted;

  /// No description provided for @postPublish.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postPublish;

  /// No description provided for @postRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get postRemovePhoto;

  /// No description provided for @postRemoved.
  ///
  /// In en, this message translates to:
  /// **'This post has been removed.'**
  String get postRemoved;

  /// No description provided for @postSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get postSave;

  /// No description provided for @postTagFriends.
  ///
  /// In en, this message translates to:
  /// **'Tag friends'**
  String get postTagFriends;

  /// No description provided for @postTagGame.
  ///
  /// In en, this message translates to:
  /// **'Tag a game'**
  String get postTagGame;

  /// No description provided for @postTaggedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 friend tagged} other{{count} friends tagged}}'**
  String postTaggedCount(int count);

  /// No description provided for @postTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get postTakePhoto;

  /// No description provided for @postTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// No description provided for @postUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get postUnlike;

  /// No description provided for @postUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get postUnsave;

  /// No description provided for @postUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated.'**
  String get postUpdated;

  /// No description provided for @postUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {current}/{total} images…'**
  String postUploading(int current, int total);

  /// No description provided for @postViewComments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View 1 comment} other{View {count} comments}}'**
  String postViewComments(int count);

  /// No description provided for @postWith.
  ///
  /// In en, this message translates to:
  /// **'With:'**
  String get postWith;

  /// No description provided for @prefBggImportCompleted.
  ///
  /// In en, this message translates to:
  /// **'BGG import finished'**
  String get prefBggImportCompleted;

  /// No description provided for @prefCommentMention.
  ///
  /// In en, this message translates to:
  /// **'Comment mentions'**
  String get prefCommentMention;

  /// No description provided for @prefEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled'**
  String get prefEventCancelled;

  /// No description provided for @prefEventCompleted.
  ///
  /// In en, this message translates to:
  /// **'Event ended'**
  String get prefEventCompleted;

  /// No description provided for @prefEventInvite.
  ///
  /// In en, this message translates to:
  /// **'Event invites'**
  String get prefEventInvite;

  /// No description provided for @prefEventKicked.
  ///
  /// In en, this message translates to:
  /// **'Removed from event'**
  String get prefEventKicked;

  /// No description provided for @prefEventLeave.
  ///
  /// In en, this message translates to:
  /// **'Someone left your event'**
  String get prefEventLeave;

  /// No description provided for @prefEventReminder.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get prefEventReminder;

  /// No description provided for @prefEventRsvp.
  ///
  /// In en, this message translates to:
  /// **'Event RSVPs'**
  String get prefEventRsvp;

  /// No description provided for @prefEventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event updates'**
  String get prefEventUpdated;

  /// No description provided for @prefFriendAccepted.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get prefFriendAccepted;

  /// No description provided for @prefFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get prefFriendRequest;

  /// No description provided for @prefInApp.
  ///
  /// In en, this message translates to:
  /// **'In-App'**
  String get prefInApp;

  /// No description provided for @prefMatchAccepted.
  ///
  /// In en, this message translates to:
  /// **'Match accepted'**
  String get prefMatchAccepted;

  /// No description provided for @prefMatchFound.
  ///
  /// In en, this message translates to:
  /// **'Match found'**
  String get prefMatchFound;

  /// No description provided for @prefPostComment.
  ///
  /// In en, this message translates to:
  /// **'Post comments'**
  String get prefPostComment;

  /// No description provided for @prefPostLike.
  ///
  /// In en, this message translates to:
  /// **'Post liked'**
  String get prefPostLike;

  /// No description provided for @prefPostTag.
  ///
  /// In en, this message translates to:
  /// **'Tagged in a post'**
  String get prefPostTag;

  /// No description provided for @prefPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get prefPush;

  /// No description provided for @prefRuleNoteApproved.
  ///
  /// In en, this message translates to:
  /// **'Rule note approved'**
  String get prefRuleNoteApproved;

  /// No description provided for @prefRuleNoteRejected.
  ///
  /// In en, this message translates to:
  /// **'Rule note rejected'**
  String get prefRuleNoteRejected;

  /// No description provided for @prefRulebookApproved.
  ///
  /// In en, this message translates to:
  /// **'Rulebook approved'**
  String get prefRulebookApproved;

  /// No description provided for @prefRulebookRejected.
  ///
  /// In en, this message translates to:
  /// **'Rulebook rejected'**
  String get prefRulebookRejected;

  /// No description provided for @prefRulebookUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Rulebook under review'**
  String get prefRulebookUnderReview;

  /// No description provided for @prefTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get prefTypeHeader;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profileBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get profileBlock;

  /// No description provided for @profileBlockMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll no longer be friends and won\'t see each other\'s content.'**
  String get profileBlockMessage;

  /// No description provided for @profileBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this user?'**
  String get profileBlockTitle;

  /// No description provided for @profileBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked.'**
  String get profileBlocked;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// No description provided for @profileDisplayNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 2 characters'**
  String get profileDisplayNameTooShort;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profileEmailNote.
  ///
  /// In en, this message translates to:
  /// **'To change your email, go to Settings › Change Email.'**
  String get profileEmailNote;

  /// No description provided for @profileFavoriteGames.
  ///
  /// In en, this message translates to:
  /// **'Favorite Games'**
  String get profileFavoriteGames;

  /// No description provided for @profileLocationHint.
  ///
  /// In en, this message translates to:
  /// **'City, Country'**
  String get profileLocationHint;

  /// No description provided for @profileNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet. Star a game you love.'**
  String get profileNoFavorites;

  /// No description provided for @profileNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get profileNoPosts;

  /// No description provided for @profileReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get profileReport;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileShare.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get profileShare;

  /// No description provided for @profileTabCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get profileTabCollection;

  /// No description provided for @profileTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileTabPosts;

  /// No description provided for @profileTabTagged.
  ///
  /// In en, this message translates to:
  /// **'Tagged'**
  String get profileTabTagged;

  /// No description provided for @profileTaggedBody.
  ///
  /// In en, this message translates to:
  /// **'Posts this player is tagged in will appear here.'**
  String get profileTaggedBody;

  /// No description provided for @profileTaggedTitle.
  ///
  /// In en, this message translates to:
  /// **'Tagged posts'**
  String get profileTaggedTitle;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This profile isn\'t available.'**
  String get profileUnavailable;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileUsernameChangeIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Can change in 1 day} other{Can change in {days} days}}'**
  String profileUsernameChangeIn(int days);

  /// No description provided for @profileUsernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'3–20 lowercase letters, numbers or underscores'**
  String get profileUsernameInvalid;

  /// No description provided for @profileVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerified;

  /// No description provided for @quietHoursBody.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are paused during quiet hours.'**
  String get quietHoursBody;

  /// No description provided for @quietHoursFrom.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String quietHoursFrom(String time);

  /// No description provided for @quietHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb'**
  String get quietHoursTitle;

  /// No description provided for @quietHoursTo.
  ///
  /// In en, this message translates to:
  /// **'To {time}'**
  String quietHoursTo(String time);

  /// No description provided for @reactivateBody.
  ///
  /// In en, this message translates to:
  /// **'This account is scheduled for deletion. Log in again within 30 days of deleting it to restore everything.'**
  String get reactivateBody;

  /// No description provided for @reactivateDone.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Your account has been restored.'**
  String get reactivateDone;

  /// No description provided for @reactivateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reactivate my account'**
  String get reactivateSubmit;

  /// No description provided for @reactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate your account?'**
  String get reactivateTitle;

  /// No description provided for @reactivateWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate with Google'**
  String get reactivateWithGoogle;

  /// No description provided for @reportComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get reportComment;

  /// No description provided for @reportPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get reportPost;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll review your report.'**
  String get reportSent;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get reportTitle;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// No description provided for @searchEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search for games, players, or events'**
  String get searchEmptyPrompt;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get searchEvents;

  /// No description provided for @searchGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get searchGames;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Meeple'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \'{query}\''**
  String searchNoResults(String query);

  /// No description provided for @searchPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get searchPlayers;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @sessionsLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String sessionsLastActive(String time);

  /// No description provided for @sessionsRevokeOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign Out All Other Devices'**
  String get sessionsRevokeOthers;

  /// No description provided for @sessionsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sessionsSignOut;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get sessionsUnknownDevice;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsBggImport.
  ///
  /// In en, this message translates to:
  /// **'BGG Import'**
  String get settingsBggImport;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric lock'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricBody.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID, fingerprint or your device PIN to open Meeple.'**
  String get settingsBiometricBody;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication isn\'t available on this device.'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline cache cleared.'**
  String get settingsCacheCleared;

  /// No description provided for @settingsChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get settingsChangeEmail;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePassword;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCache;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsExport;

  /// No description provided for @settingsExportRequested.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a download link when your export is ready.'**
  String get settingsExportRequested;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get settingsPrivacySettings;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsSessions.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions'**
  String get settingsSessions;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to log in again on this device.'**
  String get settingsSignOutMessage;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsVersion;

  /// No description provided for @statFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get statFriends;

  /// No description provided for @statGamesOwned.
  ///
  /// In en, this message translates to:
  /// **'Games Owned'**
  String get statGamesOwned;

  /// No description provided for @statMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played: {game} ({count})'**
  String statMostPlayed(String game, int count);

  /// No description provided for @statSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statSessions;

  /// No description provided for @visibilityFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get visibilityFriends;

  /// No description provided for @visibilityFriendsHint.
  ///
  /// In en, this message translates to:
  /// **'All your friends can see and join.'**
  String get visibilityFriendsHint;

  /// No description provided for @visibilityInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'Invite only'**
  String get visibilityInviteOnly;

  /// No description provided for @visibilityInviteOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Only people you invite can see it.'**
  String get visibilityInviteOnlyHint;

  /// No description provided for @visibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get visibilityPublic;

  /// No description provided for @visibilityPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone in the community can find and join.'**
  String get visibilityPublicHint;

  /// No description provided for @welcomeEvents.
  ///
  /// In en, this message translates to:
  /// **'Organize game nights with friends'**
  String get welcomeEvents;

  /// No description provided for @welcomeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track the games you own and love'**
  String get welcomeLibrary;

  /// No description provided for @welcomeMatching.
  ///
  /// In en, this message translates to:
  /// **'Get matched with friends who want to play'**
  String get welcomeMatching;

  /// No description provided for @welcomeStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeStart;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Track your games. Organize game nights. Build memories.'**
  String get welcomeTagline;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authYourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get authYourEmail;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Images must be 10 MB or smaller.'**
  String get errorFileTooLarge;

  /// No description provided for @errorUnsupportedImage.
  ///
  /// In en, this message translates to:
  /// **'Only JPEG, PNG, WebP and GIF images are allowed.'**
  String get errorUnsupportedImage;

  /// No description provided for @errorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address before logging in.'**
  String get errorEmailNotVerified;

  /// No description provided for @errorCannotInviteSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t invite yourself.'**
  String get errorCannotInviteSelf;

  /// No description provided for @errorBggImportInProgress.
  ///
  /// In en, this message translates to:
  /// **'An import is already running.'**
  String get errorBggImportInProgress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
