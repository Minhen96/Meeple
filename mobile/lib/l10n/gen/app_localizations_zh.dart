// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Meeple';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonDone => '完成';

  @override
  String get commonContinue => '继续';

  @override
  String get commonSkip => '跳过';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSend => '发送';

  @override
  String get commonShare => '分享';

  @override
  String get commonSeeAll => '查看全部';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonOops => '出错了！';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonOptional => '可选';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get commonMore => '更多';

  @override
  String get commonReadMore => '展开';

  @override
  String get commonShowLess => '收起';

  @override
  String get commonDeletedUser => '已注销用户';

  @override
  String get loadingMore => '正在加载更多…';

  @override
  String get allCaughtUp => '已经全部看完啦！';

  @override
  String get offlineBanner => '无网络连接';

  @override
  String get backOnline => '已恢复联网';

  @override
  String staleData(String age) {
    return '正在显示 $age 的缓存数据';
  }

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String get timeYesterday => '昨天';

  @override
  String timeDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get errorGeneric => '出了点问题，请重试。';

  @override
  String get errorNetwork => '无网络连接，请检查网络。';

  @override
  String get errorTimeout => '请求超时，请重试。';

  @override
  String get errorOffline => '你已离线，请在恢复联网后重试。';

  @override
  String get errorSessionExpired => '登录已过期，请重新登录。';

  @override
  String get errorForbidden => '你没有权限执行此操作。';

  @override
  String get errorNotFound => '该内容不存在或已被删除。';

  @override
  String get errorRateLimit => '请求过于频繁，请稍后再试。';

  @override
  String get errorServiceUnavailable => '服务暂时不可用，请稍后再试。';

  @override
  String get errorServer => '服务器出错了，请稍后再试。';

  @override
  String get errorEditWindowExpired => '已超过可编辑时间。';

  @override
  String get errorEventCancelled => '该活动已取消。';

  @override
  String get errorEventCompleted => '该活动已结束。';

  @override
  String get errorEventFull => '该活动已满员。';

  @override
  String get errorNotHost => '只有主办人可以执行此操作。';

  @override
  String get errorNotFriends => '仅限好友之间进行此操作。';

  @override
  String get errorRequestCooldown => '请稍后再发送好友请求。';

  @override
  String get errorPendingLimit => '待处理的好友请求过多。';

  @override
  String get errorReportLimit => '你今天的举报次数已达上限。';

  @override
  String get errorBggUserNotFound => '未找到该 BGG 用户名，请检查拼写。';

  @override
  String get errorBggUnavailable => 'BGG 目前响应缓慢，请稍后再试。';

  @override
  String get errorUsernameTooSoon => '用户名每 30 天只能修改一次。';

  @override
  String get errorUsernameTaken => '用户名已被占用';

  @override
  String get errorEmailTaken => '该邮箱已注册';

  @override
  String get errorAccountDeleted => '该账号已申请注销。';

  @override
  String get errorGoogleEmailNotVerified => '你的 Google 邮箱尚未验证。';

  @override
  String get errorGoogleAccountConflict => '该邮箱已使用密码注册，请使用密码登录。';

  @override
  String get errorGoogleFailed => 'Google 登录失败，请重试。';

  @override
  String get errorInvalidCredentials => '邮箱或密码错误。';

  @override
  String get aiRateLimit => '已达到每日 20 个问题的上限，将于 UTC 午夜重置。';

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '游戏库';

  @override
  String get navEvents => '活动';

  @override
  String get navProfile => '我的';

  @override
  String get createTitle => '创建';

  @override
  String get createPost => '发布游戏之夜';

  @override
  String get createEvent => '举办活动';

  @override
  String get createAddGame => '添加游戏';

  @override
  String get createFindMatch => '寻找玩家';

  @override
  String get pushPromptTitle => '及时了解你的游戏之夜';

  @override
  String get pushPromptBody => '接收邀请、提醒、好友请求和新评论的通知。';

  @override
  String get pushPromptAllow => '允许通知';

  @override
  String get pushPromptNotNow => '暂不';

  @override
  String get pushChannelEvents => '活动与游戏之夜';

  @override
  String get pushChannelEventsDescription => '邀请、提醒和匹配通知';

  @override
  String get pushChannelSocial => '社交动态';

  @override
  String get pushChannelSocialDescription => '点赞、评论和好友请求';

  @override
  String get appLockedTitle => 'Meeple 已锁定';

  @override
  String get appLockedBody => '使用生物识别或设备密码解锁。';

  @override
  String get appLockedUnlock => '解锁';

  @override
  String get biometricReasonUnlock => '解锁 Meeple';

  @override
  String get biometricReasonEnable => '验证身份以启用应用锁';

  @override
  String activityCollectionAdd(String name, String game) {
    return '$name 将 $game 加入了收藏。';
  }

  @override
  String activityEventCreated(String name, String event) {
    return '$name 正在举办 $event。';
  }

  @override
  String activityEventJoined(String name, String event) {
    return '$name 参加了 $event。';
  }

  @override
  String activityGeneric(String name) {
    return '$name 有新动态';
  }

  @override
  String get aiAskAnyway => '仍然提问';

  @override
  String get aiDisclaimer => 'AI 生成的回答可能并非完全准确。';

  @override
  String get aiError => '出了点问题，请重试。';

  @override
  String get aiInputHint => '提一个问题...';

  @override
  String aiNoRulebook(String game) {
    return '$game 暂无规则书。';
  }

  @override
  String get aiNoRulebookBody => '回答将基于通用知识，准确度可能较低。';

  @override
  String get aiNoRulebookTooltip => '尚未上传规则书';

  @override
  String get aiPromptSetup => '如何布置游戏？';

  @override
  String get aiPromptTurn => '我的回合要做什么？';

  @override
  String get aiPromptWin => '怎样才能获胜？';

  @override
  String get aiRulesAssistant => 'AI 规则助手';

  @override
  String aiSheetTitle(String game) {
    return '$game 规则助手';
  }

  @override
  String get authBackToSignIn => '返回登录';

  @override
  String get authCheckInbox => '请查收邮件';

  @override
  String get authConfirmNewPassword => '确认新密码';

  @override
  String get authConfirmPassword => '确认密码';

  @override
  String get authContinueWithGoogle => '使用 Google 继续';

  @override
  String get authCreateAccount => '创建账号';

  @override
  String get authCreateAccountTitle => '创建你的账号';

  @override
  String get authEmail => '邮箱';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authEmailOrUsername => '邮箱或用户名';

  @override
  String get authEmailOrUsernameRequired => '请输入邮箱或用户名';

  @override
  String get authEmailRequired => '请输入邮箱';

  @override
  String get authForgotBody => '输入注册时使用的邮箱，我们会发送重置链接。';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authForgotTitle => '重置密码';

  @override
  String get authHaveAccount => '已有账号？';

  @override
  String get authInvalidEmail => '请输入有效的邮箱地址';

  @override
  String get authIveVerified => '我已完成验证';

  @override
  String get authJoin => '加入 Meeple 社区';

  @override
  String get authNewPassword => '新密码';

  @override
  String get authNewPasswordHint => '新密码至少需要 8 个字符。';

  @override
  String get authNewPasswordTitle => '新密码';

  @override
  String get authNoAccount => '还没有账号？';

  @override
  String get authOr => '或';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordLength => '长度需为 8–128 个字符';

  @override
  String get authPasswordMin => '至少需要 8 个字符';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authPasswordUpdated => '密码已更新！';

  @override
  String get authPasswordUpdatedBody => '密码已重置，请使用新密码登录。';

  @override
  String get authPasswordsMismatch => '两次输入的密码不一致';

  @override
  String get authResendEmail => '重新发送邮件';

  @override
  String get authResetLinkExpired => '该链接已过期，请重新申请。';

  @override
  String get authResetPasswordTitle => '重置密码';

  @override
  String authResetSentTo(String email) {
    return '如果 $email 已注册，你将收到重置链接。';
  }

  @override
  String get authSendResetLink => '发送重置链接';

  @override
  String get authSetNewPassword => '设置新密码';

  @override
  String get authSignIn => '登录';

  @override
  String get authSignInLink => '登录';

  @override
  String get authSignInSubtitle => '欢迎回来';

  @override
  String get authSignUp => '创建账号';

  @override
  String get authTermsNote => '创建账号即表示你同意我们的服务条款和隐私政策。';

  @override
  String get authUsernameLength => '3–20 位小写字母、数字或下划线';

  @override
  String get authUsernameRequired => '请输入用户名';

  @override
  String get authVerificationResent => '邮件已重新发送！';

  @override
  String get authVerifyBody => '点击邮件中的链接以激活账号。';

  @override
  String get authVerifyFirst => '请先验证你的邮箱。';

  @override
  String authVerifySentTo(String email) {
    return '我们已向 $email 发送验证链接';
  }

  @override
  String get avatarChange => '更换头像';

  @override
  String get avatarCropTitle => '裁剪照片';

  @override
  String get avatarUploadFailed => '上传失败，请重试。';

  @override
  String get badgeFavorited => '最爱';

  @override
  String get badgeOwned => '已拥有';

  @override
  String get badgeWishlisted => '在心愿单中';

  @override
  String get bggImportBody => '输入 BoardGameGeek 用户名以导入你的收藏。';

  @override
  String bggImportDone(int imported, int skipped, int failed) {
    return '已导入 $imported 款游戏（跳过 $skipped 款，失败 $failed 款）。';
  }

  @override
  String get bggImportFailed => '导入失败，请重试。';

  @override
  String bggImportProgress(int processed, int total) {
    return '正在导入… $processed/$total 款游戏';
  }

  @override
  String get bggImportStart => '导入收藏';

  @override
  String get bggImportStarting => '正在开始导入…';

  @override
  String get bggImportTitle => '导入你的收藏';

  @override
  String get bggPrivacyNote => '我们只会读取你公开的收藏。';

  @override
  String get bggUsername => 'BGG 用户名';

  @override
  String get blockedEmpty => '你还没有屏蔽任何人。';

  @override
  String get blockedTitle => '已屏蔽的用户';

  @override
  String get bookmarksEmptyBody => '点击帖子上的收藏按钮即可保存到这里。';

  @override
  String get bookmarksEmptyTitle => '还没有收藏的帖子';

  @override
  String get bookmarksTitle => '已收藏的帖子';

  @override
  String get changeEmailBody => '我们会向新邮箱发送验证链接，确认后邮箱才会更改。';

  @override
  String get changeEmailCurrentPassword => '当前密码';

  @override
  String get changeEmailNew => '新邮箱';

  @override
  String changeEmailSentBody(String email) {
    return '请打开发送至 $email 的链接以确认更改。';
  }

  @override
  String get changeEmailSentTitle => '请查收新邮箱';

  @override
  String get changeEmailSubmit => '发送验证链接';

  @override
  String changePasswordBody(String email) {
    return '为了安全，修改密码需通过邮件完成。我们会向 $email 发送重置链接。';
  }

  @override
  String get changePasswordNoEmail => '请使用注册邮箱申请重置链接。';

  @override
  String get changePasswordSend => '发送重置链接';

  @override
  String get changePasswordSentBody => '请按照邮件中的链接设置新密码。';

  @override
  String get changePasswordSentTitle => '重置链接已发送';

  @override
  String get collectionNoPlays => '还没有对局记录。';

  @override
  String get collectionNotes => '备注';

  @override
  String get collectionPlayHistory => '对局记录';

  @override
  String collectionRating(String rating) {
    return '你的评分：$rating';
  }

  @override
  String get collectionRemove => '从收藏中移除';

  @override
  String collectionRemoveMessage(String game) {
    return '$game 将从你的收藏、心愿单和最爱中移除。';
  }

  @override
  String get collectionRemoveTitle => '移除这款游戏？';

  @override
  String get commentDeleteMessage => '该评论将被删除。';

  @override
  String get commentDeleteTitle => '删除评论？';

  @override
  String get commentEditTitle => '编辑评论';

  @override
  String get deleteConfirmMessage => '你的账号将被删除。30 天内重新登录即可恢复。';

  @override
  String get deleteConfirmTitle => '你确定吗？';

  @override
  String get deleteDone => '你的账号已安排删除。';

  @override
  String get deletePasswordless => '我使用 Google 注册（没有密码）';

  @override
  String get deleteSubmit => '删除我的账号';

  @override
  String get deleteTypeConfirm => '输入 DELETE 以确认';

  @override
  String get deleteTypeConfirmError => '请输入 DELETE';

  @override
  String get deleteWarning =>
      '你的账号将立即停用，并在 30 天后永久删除。你的收藏、好友关系、匹配请求和通知会立即移除；帖子和评论将显示为“已注销用户”。30 天内登录即可恢复。';

  @override
  String get eventAccept => '接受';

  @override
  String get eventCancelConfirm => '取消活动';

  @override
  String get eventCancelMessage => '已参加或受邀的所有人都会收到通知。';

  @override
  String get eventCancelTitle => '取消此活动？';

  @override
  String get eventCancelledBanner => '该活动已取消。';

  @override
  String get eventChangeToGoing => '改为参加';

  @override
  String get eventChooseFriends => '选择好友';

  @override
  String get eventCreated => '活动已创建！';

  @override
  String get eventCreatedInvites => '活动已创建！邀请已发送。';

  @override
  String get eventDateInPast => '请选择未来的日期。';

  @override
  String get eventDateRequired => '请选择日期和时间。';

  @override
  String get eventDecline => '拒绝';

  @override
  String eventDefaultTitle(String game) {
    return '$game 之夜';
  }

  @override
  String get eventEdit => '编辑活动';

  @override
  String get eventEndedBanner => '该活动已结束。';

  @override
  String get eventFieldDateTime => '日期和时间';

  @override
  String get eventFieldDescription => '描述（可选）';

  @override
  String get eventFieldGame => '游戏';

  @override
  String get eventFieldLocation => '地点';

  @override
  String get eventFieldMaxPlayers => '人数上限';

  @override
  String get eventFieldTitle => '活动标题';

  @override
  String get eventFieldVisibility => '谁可以看到';

  @override
  String get eventFull => '活动已满员';

  @override
  String eventGoingCount(int count) {
    return '$count 人参加';
  }

  @override
  String eventHostedBy(String name) {
    return '由 $name 主办';
  }

  @override
  String get eventInviteFriends => '邀请好友';

  @override
  String eventInvitedCount(int count) {
    return '已邀请 $count 人';
  }

  @override
  String get eventInvitesSent => '邀请已发送。';

  @override
  String get eventJoin => '参加';

  @override
  String get eventJoined => '你已报名参加！';

  @override
  String get eventKick => '移出';

  @override
  String eventKickMessage(String name) {
    return '$name 将被移出此活动。';
  }

  @override
  String get eventKickTitle => '移出参与者？';

  @override
  String get eventLeave => '退出活动';

  @override
  String get eventLeaveMessage => '你的名额将空出给其他人。';

  @override
  String get eventLeaveTitle => '退出此活动？';

  @override
  String get eventLocationHint => '地址、场地名称或“线上”';

  @override
  String get eventManage => '管理活动';

  @override
  String get eventNoMemories => '还没有分享回忆。';

  @override
  String get eventNotFound => '该活动不存在或已被删除。';

  @override
  String get eventPickDate => '选择日期';

  @override
  String get eventPickGame => '搜索游戏';

  @override
  String get eventPickTime => '选择时间';

  @override
  String eventPlayersCount(int count, int max) {
    return '$count/$max 名玩家';
  }

  @override
  String get eventRemoveGame => '移除游戏';

  @override
  String get eventStatusCancelled => '已取消';

  @override
  String get eventStatusCompleted => '已结束';

  @override
  String get eventStatusFull => '已满员';

  @override
  String get eventStatusOpen => '开放中';

  @override
  String get eventTitleTooShort => '标题至少需要 3 个字符';

  @override
  String get eventUpdated => '活动已更新。';

  @override
  String get eventViewMemories => '查看回忆';

  @override
  String get eventYouWereRemoved => '主办人已将你移出此活动。';

  @override
  String get eventsCalendarView => '日历视图';

  @override
  String get eventsEmptyPastBody => '你的游戏之夜记录会显示在这里。';

  @override
  String get eventsEmptyPastTitle => '没有过往活动。';

  @override
  String get eventsEmptyUpcomingBody => '来举办下一场游戏之夜吧！';

  @override
  String get eventsEmptyUpcomingTitle => '暂无即将开始的活动。';

  @override
  String get eventsListView => '列表视图';

  @override
  String get eventsNoneThisMonth => '本月没有活动。';

  @override
  String get eventsTabMine => '我的';

  @override
  String get eventsTabPast => '过往';

  @override
  String get eventsTabUpcoming => '即将开始';

  @override
  String get eventsTitle => '活动';

  @override
  String get filter1to2h => '1–2 小时';

  @override
  String get filter30to60 => '30–60 分钟';

  @override
  String get filterHeavy => '重度';

  @override
  String get filterLight => '轻度';

  @override
  String get filterMedium => '中度';

  @override
  String get filterOver2h => '2 小时以上';

  @override
  String filterPlayers(int count) {
    return '$count+ 人';
  }

  @override
  String get filterUnder30 => '30 分钟内';

  @override
  String get friendAccept => '接受';

  @override
  String get friendAdd => '加好友';

  @override
  String get friendCancelMessage => '你的好友请求将被撤回。';

  @override
  String get friendCancelRequest => '撤回请求';

  @override
  String get friendCancelTitle => '撤回好友请求？';

  @override
  String get friendDecline => '拒绝';

  @override
  String get friendFriends => '好友';

  @override
  String get friendPending => '等待回应';

  @override
  String friendPickerDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '完成（$count）',
      zero: '完成',
    );
    return '$_temp0';
  }

  @override
  String get friendPickerEmpty => '没有可显示的好友。';

  @override
  String get friendPickerSearch => '搜索好友';

  @override
  String get friendRequestSent => '好友请求已发送。';

  @override
  String get friendUnblock => '取消屏蔽';

  @override
  String get friendUnfriend => '删除好友';

  @override
  String get friendUnfriendMessage => '你们将无法再看到对方仅好友可见的内容。';

  @override
  String get friendUnfriendTitle => '删除好友？';

  @override
  String get friendsEmptyBody => '找到一起玩的人，加为好友吧。';

  @override
  String get friendsEmptyTitle => '还没有好友';

  @override
  String get friendsNoRequests => '没有待处理的好友请求。';

  @override
  String get friendsNoSuggestions => '暂无推荐，请通过用户名搜索好友。';

  @override
  String get friendsReceived => '收到的请求';

  @override
  String get friendsSearchHint => '按名称或用户名搜索';

  @override
  String get friendsSent => '发出的请求';

  @override
  String get friendsSuggestions => '你可能认识的人';

  @override
  String get friendsTabFind => '查找';

  @override
  String get friendsTabFriends => '好友';

  @override
  String get friendsTabRequests => '请求';

  @override
  String get friendsTitle => '好友';

  @override
  String get gameAddToCollection => '加入收藏';

  @override
  String get gameAddedToCollection => '已加入收藏！';

  @override
  String get gameBackToLibrary => '返回游戏库';

  @override
  String gameBggRating(String rating) {
    return 'BGG 评分 $rating';
  }

  @override
  String get gameCategories => '分类';

  @override
  String get gameFavorite => '加入最爱';

  @override
  String gameFriendRating(String rating, int count) {
    return '$count 位好友平均 $rating 分';
  }

  @override
  String get gameInCollection => '已在收藏中';

  @override
  String get gameInfoComplexity => '复杂度';

  @override
  String get gameInfoDuration => '时长';

  @override
  String get gameInfoPlayers => '人数';

  @override
  String get gameLogPlay => '记录对局';

  @override
  String get gameMechanics => '机制';

  @override
  String gameMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get gameNoFriendsOwn => '你的好友还没有人拥有这款游戏。';

  @override
  String get gameNoReviews => '好友还没有评价。';

  @override
  String get gameNoSessions => '还没有对局记录。';

  @override
  String get gameNotFound => '该游戏不存在或已被删除。';

  @override
  String get gameOnWishlist => '已在心愿单';

  @override
  String gameOwnedByFriends(int count) {
    return '$count 位好友拥有';
  }

  @override
  String gamePlayers(String range) {
    return '$range 人';
  }

  @override
  String gamePlays(int count) {
    return '$count 次对局';
  }

  @override
  String get gameTabFriends => '好友';

  @override
  String get gameTabOverview => '概览';

  @override
  String get gameTabReviews => '评价';

  @override
  String get gameTabSessions => '对局';

  @override
  String get gameUnfavorite => '移出最爱';

  @override
  String get gameWishlist => '心愿单';

  @override
  String greetingAfternoon(String name) {
    return '下午好，$name！';
  }

  @override
  String greetingEvening(String name) {
    return '晚上好，$name！';
  }

  @override
  String greetingMorning(String name) {
    return '早上好，$name！';
  }

  @override
  String greetingNextSession(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '你的下一场游戏在 $days 天后。',
      one: '你的下一场游戏在明天。',
      zero: '你的下一场游戏就在今天。',
    );
    return '$_temp0';
  }

  @override
  String get greetingNoEvents => '暂无即将开始的活动。';

  @override
  String get homeCreatePost => '发布帖子';

  @override
  String get homeEmptyBody => '你的好友最近没有发帖。';

  @override
  String get homeEmptyNoFriendsBody => '添加好友，看看他们在玩什么。';

  @override
  String get homeEmptyNoFriendsTitle => '你的动态很安静。';

  @override
  String get homeEmptyTitle => '暂时没有新内容。';

  @override
  String get homeFeedError => '无法加载动态。';

  @override
  String get homeFeedTitle => '动态';

  @override
  String get homeFindFriends => '寻找好友';

  @override
  String get homeMatchesTitle => '匹配推荐';

  @override
  String homeMoreMatches(int count) {
    return '还有 $count 个';
  }

  @override
  String get homeUpcomingTitle => '即将开始';

  @override
  String get homeViewCalendar => '查看日历';

  @override
  String get htpActions => '行动';

  @override
  String get htpEnd => '游戏结束';

  @override
  String get htpFailed => '无法生成玩法指南。';

  @override
  String get htpFaq => '常见问题';

  @override
  String get htpGenerate => '生成指南';

  @override
  String htpGenerating(int progress) {
    return '生成中… $progress%';
  }

  @override
  String get htpNotGenerated => '还没有玩法指南。';

  @override
  String get htpObjective => '目标';

  @override
  String get htpOverview => '概述';

  @override
  String get htpResources => '资源';

  @override
  String get htpRules => '规则';

  @override
  String get htpScoring => '计分';

  @override
  String get htpSetup => '准备';

  @override
  String get htpTips => '技巧';

  @override
  String get htpTitle => '玩法指南';

  @override
  String get htpTurns => '回合流程';

  @override
  String get htpUnavailable => '指南暂时不可用。';

  @override
  String get htpWinning => '获胜条件';

  @override
  String get libraryBrowseGames => '浏览游戏';

  @override
  String get libraryDatabaseUnavailable => '游戏数据库不可用。';

  @override
  String get libraryEmptyCollectionBody => '搜索游戏并加入你的收藏。';

  @override
  String get libraryEmptyCollectionTitle => '你的游戏架还是空的。';

  @override
  String get libraryEmptyFavoritesBody => '把你喜欢的游戏设为最爱吧。';

  @override
  String get libraryEmptyFavoritesTitle => '还没有最爱。';

  @override
  String get libraryEmptyWishlistBody => '浏览游戏库，添加你想要的游戏。';

  @override
  String get libraryEmptyWishlistTitle => '心愿单里还没有游戏。';

  @override
  String get libraryNoGames => '没有可显示的游戏。';

  @override
  String libraryNoResults(String query) {
    return '没有找到与“$query”相关的游戏。';
  }

  @override
  String get libraryNoResultsHint => '请尝试其他拼写或减少筛选条件。';

  @override
  String get librarySearchHint => '搜索游戏';

  @override
  String get libraryTabAll => '全部游戏';

  @override
  String get libraryTabCollection => '我的收藏';

  @override
  String get libraryTabFavorites => '最爱';

  @override
  String get libraryTabWishlist => '心愿单';

  @override
  String get libraryTitle => '游戏库';

  @override
  String get matchActiveRequests => '进行中的请求';

  @override
  String get matchAvailableFrom => '可用开始时间';

  @override
  String matchAvailableRange(String from, String to) {
    return '可用时间 $from – $to';
  }

  @override
  String get matchAvailableUntil => '可用结束时间';

  @override
  String get matchDismiss => '忽略';

  @override
  String get matchFormBody => '我们会为你匹配想在同一时间玩同一款游戏的好友。';

  @override
  String get matchFormTitle => '寻找玩家';

  @override
  String matchFriendsWantToPlay(int count, String game) {
    return '$count 位好友想玩 $game';
  }

  @override
  String matchFromValue(String time) {
    return '从 $time';
  }

  @override
  String get matchInvalidRange => '结束时间必须晚于开始时间。';

  @override
  String get matchNoRequests => '没有进行中的匹配请求。';

  @override
  String get matchNoSuggestions => '暂时没有匹配推荐。';

  @override
  String get matchPickGameFirst => '请先选择游戏。';

  @override
  String get matchRequestCreated => '匹配请求已创建。';

  @override
  String get matchSubmit => '开玩吧！';

  @override
  String matchUntilValue(String time) {
    return '至 $time';
  }

  @override
  String get matchingTitle => '匹配';

  @override
  String get minutesSuffix => '分钟';

  @override
  String notifBggImportCompleted(int count) {
    return 'BGG 导入完成：已添加 $count 款游戏。';
  }

  @override
  String notifCommentMention(String name) {
    return '$name 在评论中提到了你';
  }

  @override
  String notifEventCancelled(String event) {
    return '$event 已取消';
  }

  @override
  String notifEventCompleted(String event) {
    return '$event 已结束，来分享回忆吧！';
  }

  @override
  String notifEventInvite(String name, String event) {
    return '$name 邀请你参加 $event';
  }

  @override
  String notifEventKicked(String event) {
    return '你已被移出 $event';
  }

  @override
  String notifEventLeave(String name, String event) {
    return '$name 退出了 $event';
  }

  @override
  String notifEventReminder(String event) {
    return '$event 即将开始';
  }

  @override
  String notifEventRsvp(String name, String event) {
    return '$name 将参加 $event';
  }

  @override
  String notifEventUpdated(String event) {
    return '$event 已更新';
  }

  @override
  String notifFriendAccepted(String name) {
    return '$name 接受了你的好友请求';
  }

  @override
  String notifFriendRequest(String name) {
    return '$name 向你发送了好友请求';
  }

  @override
  String notifMatchAccepted(String name, String game) {
    return '$name 接受了 $game 的匹配';
  }

  @override
  String notifMatchFound(String game) {
    return '找到了 $game 的新匹配';
  }

  @override
  String notifPostComment(String name) {
    return '$name 评论了你的帖子';
  }

  @override
  String notifPostLike(String name) {
    return '$name 赞了你的帖子';
  }

  @override
  String notifPostTag(String name) {
    return '$name 在帖子中标记了你';
  }

  @override
  String notifRuleNoteApproved(String game) {
    return '你为 $game 提交的规则笔记已通过';
  }

  @override
  String notifRuleNoteRejected(String game) {
    return '你为 $game 提交的规则笔记未通过';
  }

  @override
  String notifRulebookApproved(String game) {
    return '$game 的规则书已通过审核';
  }

  @override
  String notifRulebookRejected(String game) {
    return '$game 的规则书未通过审核';
  }

  @override
  String notifRulebookUnderReview(String game) {
    return '$game 的规则书正在审核中';
  }

  @override
  String get notificationAGame => '一款游戏';

  @override
  String get notificationAnEvent => '一场活动';

  @override
  String get notificationPrefsTitle => '通知偏好';

  @override
  String get notificationSomeone => '有人';

  @override
  String get notificationsEarlier => '更早';

  @override
  String get notificationsEmptyBody => '通知会显示在这里。';

  @override
  String get notificationsMarkAllRead => '全部已读';

  @override
  String get notificationsMarkRead => '标为已读';

  @override
  String get notificationsThisWeek => '本周';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notificationsToday => '今天';

  @override
  String get onboardingAddGameBody => '添加几款你拥有的游戏，开始吧。';

  @override
  String onboardingAddGameConfirm(String game) {
    return '将 $game 加入你的收藏？';
  }

  @override
  String get onboardingAddGameTitle => '你喜欢玩什么？';

  @override
  String get onboardingBggBody => '已经在用 BoardGameGeek？把收藏搬过来吧。';

  @override
  String get onboardingBggTitle => '从 BoardGameGeek 导入';

  @override
  String get onboardingFinish => '完成';

  @override
  String get onboardingFriendsBody => '向一起玩的人发送好友请求。';

  @override
  String get onboardingFriendsTitle => '寻找你的好友';

  @override
  String get onboardingPopular => '热门游戏';

  @override
  String get onboardingProfileBody => '添加头像和名字，让好友认出你。';

  @override
  String get onboardingProfileTitle => '设置个人资料';

  @override
  String get playDate => '对局日期';

  @override
  String get playDuration => '时长';

  @override
  String get playFewerPlayers => '减少';

  @override
  String playLogTitle(String game) {
    return '记录 $game 的对局';
  }

  @override
  String get playLogged => '对局已记录！';

  @override
  String get playMorePlayers => '增加';

  @override
  String get playNotes => '备注（可选）';

  @override
  String get playPlayers => '玩家人数';

  @override
  String get postAddComment => '添加评论…';

  @override
  String get postAddPhotos => '添加照片';

  @override
  String get postCaptionHint => '桌上发生了什么？';

  @override
  String get postComment => '评论';

  @override
  String postCommentsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条评论',
      zero: '评论',
    );
    return '$_temp0';
  }

  @override
  String get postCompressing => '正在压缩…';

  @override
  String get postDelete => '删除帖子';

  @override
  String get postDeleteMessage => '该帖子将对所有人删除。';

  @override
  String get postDeleteTitle => '删除这条帖子？';

  @override
  String get postDeleted => '帖子已删除。';

  @override
  String get postDiscard => '放弃';

  @override
  String get postDiscardChangesMessage => '你对这条帖子的修改将会丢失。';

  @override
  String get postDiscardChangesTitle => '放弃修改？';

  @override
  String get postDiscardMessage => '你的照片和文字将会丢失。';

  @override
  String get postDiscardTitle => '放弃这条帖子？';

  @override
  String get postEditTitle => '编辑帖子';

  @override
  String get postEdited => '已编辑';

  @override
  String get postEmptyError => '请添加照片或文字。';

  @override
  String get postFirstComment => '来发表第一条评论吧！';

  @override
  String get postLike => '点赞';

  @override
  String postLikes(int count) {
    return '$count 个赞';
  }

  @override
  String get postNewTitle => '新帖子';

  @override
  String postPlayedOn(String date) {
    return '对局日期：$date';
  }

  @override
  String get postPosted => '已发布！';

  @override
  String get postPublish => '发布';

  @override
  String get postRemovePhoto => '移除照片';

  @override
  String get postRemoved => '该帖子已被删除。';

  @override
  String get postSave => '收藏';

  @override
  String get postTagFriends => '标记好友';

  @override
  String get postTagGame => '标记游戏';

  @override
  String postTaggedCount(int count) {
    return '已标记 $count 位好友';
  }

  @override
  String get postTakePhoto => '拍照';

  @override
  String get postTitle => '帖子';

  @override
  String get postUnlike => '取消点赞';

  @override
  String get postUnsave => '取消收藏';

  @override
  String get postUpdated => '帖子已更新。';

  @override
  String postUploading(int current, int total) {
    return '正在上传第 $current/$total 张图片…';
  }

  @override
  String postViewComments(int count) {
    return '查看 $count 条评论';
  }

  @override
  String get postWith => '一起玩：';

  @override
  String get prefBggImportCompleted => 'BGG 导入完成';

  @override
  String get prefCommentMention => '评论中提到我';

  @override
  String get prefEventCancelled => '活动取消';

  @override
  String get prefEventCompleted => '活动结束';

  @override
  String get prefEventInvite => '活动邀请';

  @override
  String get prefEventKicked => '被移出活动';

  @override
  String get prefEventLeave => '有人退出你的活动';

  @override
  String get prefEventReminder => '活动提醒';

  @override
  String get prefEventRsvp => '活动报名';

  @override
  String get prefEventUpdated => '活动更新';

  @override
  String get prefFriendAccepted => '好友请求被接受';

  @override
  String get prefFriendRequest => '好友请求';

  @override
  String get prefInApp => '应用内';

  @override
  String get prefMatchAccepted => '匹配被接受';

  @override
  String get prefMatchFound => '找到匹配';

  @override
  String get prefPostComment => '帖子评论';

  @override
  String get prefPostLike => '帖子被点赞';

  @override
  String get prefPostTag => '在帖子中被标记';

  @override
  String get prefPush => '推送';

  @override
  String get prefRuleNoteApproved => '规则笔记通过';

  @override
  String get prefRuleNoteRejected => '规则笔记未通过';

  @override
  String get prefRulebookApproved => '规则书通过';

  @override
  String get prefRulebookRejected => '规则书未通过';

  @override
  String get prefRulebookUnderReview => '规则书审核中';

  @override
  String get prefTypeHeader => '通知类型';

  @override
  String get profileBio => '个人简介';

  @override
  String get profileBlock => '屏蔽';

  @override
  String get profileBlockMessage => '你们将不再是好友，也看不到对方的内容。';

  @override
  String get profileBlockTitle => '屏蔽该用户？';

  @override
  String get profileBlocked => '已屏蔽该用户。';

  @override
  String get profileDisplayName => '显示名称';

  @override
  String get profileDisplayNameTooShort => '至少需要 2 个字符';

  @override
  String get profileEdit => '编辑资料';

  @override
  String get profileEmailNote => '如需更改邮箱，请前往 设置 › 更改邮箱。';

  @override
  String get profileFavoriteGames => '最爱的游戏';

  @override
  String get profileLocationHint => '城市，国家';

  @override
  String get profileNoFavorites => '还没有最爱，为喜欢的游戏点亮星标吧。';

  @override
  String get profileNoPosts => '还没有帖子。';

  @override
  String get profileReport => '举报';

  @override
  String get profileSaved => '资料已保存。';

  @override
  String get profileShare => '分享主页';

  @override
  String get profileTabCollection => '收藏';

  @override
  String get profileTabPosts => '帖子';

  @override
  String get profileTabTagged => '被标记';

  @override
  String get profileTaggedBody => '该玩家被标记的帖子会显示在这里。';

  @override
  String get profileTaggedTitle => '被标记的帖子';

  @override
  String get profileUnavailable => '该主页不可用。';

  @override
  String get profileUsername => '用户名';

  @override
  String profileUsernameChangeIn(int days) {
    return '$days 天后可修改';
  }

  @override
  String get profileUsernameInvalid => '3–20 位小写字母、数字或下划线';

  @override
  String get profileVerified => '已认证';

  @override
  String get quietHoursBody => '免打扰时段内将暂停推送通知。';

  @override
  String quietHoursFrom(String time) {
    return '从 $time';
  }

  @override
  String get quietHoursTitle => '免打扰';

  @override
  String quietHoursTo(String time) {
    return '至 $time';
  }

  @override
  String get reactivateBody => '该账号已申请注销。在注销后 30 天内重新登录即可恢复所有数据。';

  @override
  String get reactivateDone => '欢迎回来！你的账号已恢复。';

  @override
  String get reactivateSubmit => '恢复我的账号';

  @override
  String get reactivateTitle => '恢复你的账号？';

  @override
  String get reactivateWithGoogle => '使用 Google 恢复';

  @override
  String get reportComment => '举报评论';

  @override
  String get reportPost => '举报帖子';

  @override
  String get reportReasonHarassment => '骚扰或欺凌';

  @override
  String get reportReasonInappropriate => '不当内容';

  @override
  String get reportReasonOther => '其他原因';

  @override
  String get reportReasonSpam => '垃圾信息';

  @override
  String get reportSent => '谢谢，我们会审核你的举报。';

  @override
  String get reportTitle => '你举报的原因是？';

  @override
  String get searchClear => '清除';

  @override
  String get searchEmptyPrompt => '搜索游戏、玩家或活动';

  @override
  String get searchEvents => '活动';

  @override
  String get searchGames => '游戏';

  @override
  String get searchHint => '搜索 Meeple';

  @override
  String searchNoResults(String query) {
    return '没有“$query”的结果';
  }

  @override
  String get searchPlayers => '玩家';

  @override
  String get searchRecent => '最近搜索';

  @override
  String get sessionsInvalid => '无法验证此设备的会话。列表已刷新，请重试。';

  @override
  String sessionsLastActive(String time) {
    return '最近活跃：$time';
  }

  @override
  String get sessionsRevokeOthers => '退出其他所有设备';

  @override
  String get sessionsSignOut => '退出';

  @override
  String get sessionsThisDevice => '本设备';

  @override
  String get sessionsUnknownDevice => '未知设备';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsBggImport => 'BGG 导入';

  @override
  String get settingsBiometric => '生物识别锁';

  @override
  String get settingsBiometricBody => '打开 Meeple 时需要面容、指纹或设备密码。';

  @override
  String get settingsBiometricUnavailable => '此设备不支持生物识别验证。';

  @override
  String get settingsCacheCleared => '离线缓存已清除。';

  @override
  String get settingsChangeEmail => '更改邮箱';

  @override
  String get settingsChangePassword => '修改密码';

  @override
  String get settingsClearCache => '清除缓存';

  @override
  String get settingsComingSoon => '即将推出';

  @override
  String get settingsDeleteAccount => '删除账号';

  @override
  String get settingsEditProfile => '编辑资料';

  @override
  String get settingsExport => '导出我的数据';

  @override
  String get settingsExportRequested => '导出完成后，我们会通过邮件发送下载链接。';

  @override
  String get settingsFeedback => '发送反馈';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsPrivacyPolicy => '隐私政策';

  @override
  String get settingsPrivacySettings => '隐私设置';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsSessions => '登录设备';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get settingsSignOutMessage => '你需要在此设备上重新登录。';

  @override
  String get settingsSignOutTitle => '退出登录？';

  @override
  String get settingsTerms => '服务条款';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsVersion => '应用版本';

  @override
  String get statFriends => '好友';

  @override
  String get statGamesOwned => '拥有游戏';

  @override
  String statMostPlayed(String game, int count) {
    return '玩得最多：$game（$count 次）';
  }

  @override
  String get statSessions => '对局';

  @override
  String get visibilityFriends => '好友';

  @override
  String get visibilityFriendsHint => '你的所有好友都可以查看和加入。';

  @override
  String get visibilityInviteOnly => '仅受邀';

  @override
  String get visibilityInviteOnlyHint => '只有受邀的人可以看到。';

  @override
  String get visibilityPublic => '公开';

  @override
  String get visibilityPublicHint => '社区中的任何人都可以找到并加入。';

  @override
  String get welcomeEvents => '和好友组织游戏之夜';

  @override
  String get welcomeLibrary => '记录你拥有和喜爱的游戏';

  @override
  String get welcomeMatching => '与想玩的好友自动匹配';

  @override
  String get welcomeStart => '开始';

  @override
  String get welcomeTagline => '记录游戏，组织聚会，留下回忆。';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authYourEmail => '你的邮箱';

  @override
  String get errorFileTooLarge => '图片不能超过 10 MB。';

  @override
  String get errorUnsupportedImage => '仅支持 JPEG、PNG、WebP 和 GIF 图片。';

  @override
  String get errorEmailNotVerified => '登录前请先验证邮箱。';

  @override
  String get errorCannotInviteSelf => '不能邀请你自己。';

  @override
  String get errorBggImportInProgress => '已有导入正在进行。';
}
