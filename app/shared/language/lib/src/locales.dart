import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n/messages_all.dart';

class L {
  static Future<L> load(Locale locale) {
    final name = locale.countryCode!.isEmpty ? locale.languageCode : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return L();
    });
  }

  static L of(BuildContext context) => Localizations.of<L>(context, L)!;

  String get toLightMode {
    return Intl.message(
      'Light mode',
      name: 'toLightMode',
      desc: 'tooltip',
    );
  }

  String get toDarkMode {
    return Intl.message(
      'Dark mode',
      name: 'toDarkMode',
      desc: 'tooltip',
    );
  }

  String get tables {
    return Intl.message(
      'tables',
      name: 'tables',
      desc: 'Database inspector pane',
    );
  }

  String get routines {
    return Intl.message(
      'routines',
      name: 'routines',
      desc: 'Database inspector pane',
    );
  }

  String get columns {
    return Intl.message(
      'columns',
      name: 'columns',
      desc: 'Database inspector pane',
    );
  }

  String get triggers {
    return Intl.message(
      'triggers',
      name: 'triggers',
      desc: 'Database inspector pane',
    );
  }

  String get primaryKey {
    return Intl.message(
      'Primary Key',
      name: 'primaryKey',
      desc: 'Database inspector pane',
    );
  }

  String get foreignKey {
    return Intl.message(
      'Foreign Key',
      name: 'foreignKey',
      desc: 'Database inspector pane',
    );
  }

  String get nonNullable {
    return Intl.message(
      'Non-nullable',
      name: 'nonNullable',
      desc: 'Database inspector pane',
    );
  }

  String get copyToClipboard {
    return Intl.message(
      'Copy to clipboard',
      name: 'copyToClipboard',
      desc: 'Generic label',
    );
  }

  String get copied {
    return Intl.message(
      'Copied!',
      name: 'copied',
      desc: 'Generic label',
    );
  }

  String get search {
    return Intl.message(
      'Search',
      name: 'search',
      desc: 'Generic label',
    );
  }

  String get query {
    return Intl.message(
      'Query',
      name: 'query',
      desc: 'Generic label',
    );
  }

  String get clearSearch {
    return Intl.message(
      'Clear search',
      name: 'clearSearch',
      desc: 'Generic label',
    );
  }

  String score(String value) {
    return Intl.message(
      'Score: $value',
      name: 'score',
      desc: 'Search relevance score',
      args: [value],
    );
  }

  String found(String value) {
    return Intl.message(
      'Found: $value',
      name: 'score',
      desc: 'Search relevance score',
      args: [value],
      examples: const {'value': 'Found: +10000'},
    );
  }

  String get close {
    return Intl.message(
      'Close',
      name: 'close',
      desc: 'Generic label',
    );
  }

  String get filter {
    return Intl.message(
      'Filter',
      name: 'filter',
      desc: 'Generic label, verb',
    );
  }

  String get byClient {
    return Intl.message(
      'By client',
      name: 'byClient',
      desc: 'Filter label, as in "filter by client"',
    );
  }

  String get byPlatform {
    return Intl.message(
      'By platform',
      name: 'byPlatform',
      desc: 'Filter label, as in "filter by platform"',
    );
  }

  String get noAppliedFilters {
    return Intl.message(
      'No applied filters',
      name: 'noAppliedFilters',
      desc: 'Filter bar, empty state',
    );
  }

  String removeFilter(String filter) {
    return Intl.message(
      'Remove filter $filter',
      name: 'removeFilter',
      desc: 'Filter bar, hint',
    );
  }

  String get clearFilters {
    return Intl.message(
      'Clear filters',
      name: 'clearFilters',
      desc: 'Filter bar, hint',
    );
  }

  String get expandAll {
    return Intl.message(
      'Expand all',
      name: 'expandAll',
      desc: 'Generic label',
    );
  }

  String get collapseAll {
    return Intl.message(
      'Collapse all',
      name: 'collapseAll',
      desc: 'Generic label',
    );
  }

  String get rerunQuery {
    return Intl.message(
      'Re-run query',
      name: 'rerunQuery',
      desc: 'Generic label',
    );
  }

  String get runQuery {
    return Intl.message(
      'Run query',
      name: 'runQuery',
      desc: 'Generic label',
    );
  }

  String get runQueryAndStartThread {
    return Intl.message(
      'Run query and start thread',
      name: 'runQueryAndStartConversation',
      desc: 'SQL query console menu item',
    );
  }

  String get shareLink {
    return Intl.message(
      'Share link',
      name: 'shareLink',
      desc: 'Label that allows to share a URL to something',
    );
  }

  String get deleteThread {
    return Intl.message(
      'Delete this thread?',
      name: 'deleteThread',
      desc: 'Thread menu item',
    );
  }

  String get cannotBeUndone {
    return Intl.message(
      'This cannot be undone',
      name: 'cannotBeUndone',
      desc: 'Thread menu item',
    );
  }

  String get threadsEmptyStateTitle {
    return Intl.message(
      'This is Threads, \nconversations with ChatGPT',
      name: 'threadsEmptyStateBody',
      desc: 'Threads empty state copy',
    );
  }

  String get threadsEmptyStateBody {
    return Intl.message(
      'Nothing here yet.\nA thread always starts with an SQL query and a prompt.\nFrom your console, highlight the query you want to run and submit to ChatGPT, right-click (on Windows) or two-finger tap (on MacOS) on the highlighted query and choose "$runQueryAndStartThread" in the context menu. This will open an new thread and suggest to submit a ChatGPT prompt. Ask you question and press the paper plane button. This will initiate a conversation',
      name: 'threadsEmptyStateBody',
      desc: 'Threads empty state copy',
    );
  }

  String get refresh {
    return Intl.message(
      'Refresh',
      name: 'refresh',
      desc: 'Generic label',
    );
  }

  String get share {
    return Intl.message(
      'Share',
      name: 'share',
      desc: 'Generic label',
    );
  }

  String get exportToCsv {
    return Intl.message(
      'Export to CSV',
      name: 'exportToCsv',
      desc: 'Generic label',
    );
  }

  String get info {
    return Intl.message(
      'Info',
      name: 'info',
      desc: 'Generic label',
    );
  }

  String get goToStash {
    return Intl.message(
      'Go to Stash',
      name: 'goToStash',
      desc: 'Button label',
    );
  }

  String get openThreads {
    return Intl.message(
      'Open threads',
      name: 'startThread',
      desc: 'Button label',
    );
  }

  String get closeThreads {
    return Intl.message(
      'Close threads',
      name: 'closeThreads',
      desc: 'Button label',
    );
  }

  String get toListView {
    return Intl.message(
      'To all threads',
      name: 'toListView',
      desc: 'Button label',
    );
  }

  String get askChatGPT {
    return Intl.message(
      'Ask ChatGPT',
      name: 'askChatGPT',
      desc: 'Button label',
    );
  }

  String get stashEmptyStateTitle {
    return Intl.message(
      'This is your stash',
      name: 'stashEmptyState',
      desc: 'Button label',
    );
  }

  String get temperatureDefinition {
    return Intl.message(
      'You can think of temperature like randomness, with 0 being least random (or most deterministic) and 2 being most random (least deterministic). When using low values for temperature (e.g. 0.2) the model responses will tend to be more consistent but may feel more robotic. Values higher than 1.0, especially values close to 2.0, can lead to erratic model outputs. If your goal is creative outputs, a combination of a slightly higher than normal temperature (e.g. 1.2) combined with a prompt specifically asking the model to be creative may be your best bet, but we encourage experimentation.',
      name: 'temperatureDefinition',
      desc: 'Tooltip',
    );
  }

  String temperatureLabel(double v) {
    return Intl.message(
      'Temperature: $v',
      name: 'temperatureLabel',
      desc: 'Chat label',
    );
  }

  String modelLabel(String v) {
    return Intl.message(
      'Model: $v',
      name: 'modelLabel',
      desc: 'Chat label',
    );
  }

  String get stashEmptyStateBody {
    return Intl.message(
      'Here you can store your queries and prompts and re-use them later',
      name: 'stashEmptyState',
      desc: 'Button label',
    );
  }

  String get queries {
    return Intl.message(
      'Queries',
      name: 'queries',
      desc: 'Button label',
    );
  }

  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: 'Button label',
    );
  }

  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: 'Button label',
    );
  }

  String get add {
    return Intl.message(
      'Add',
      name: 'add',
      desc: 'Button label',
    );
  }

  String get prompts {
    return Intl.message(
      'Prompts',
      name: 'prompts',
      desc: 'Button label',
    );
  }

  String get name {
    return Intl.message(
      'Name',
      name: 'name',
      desc: 'Generic label',
    );
  }

  String get edit {
    return Intl.message(
      'Edit',
      name: 'edit',
      desc: 'Generic label',
    );
  }

  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: 'Generic label',
    );
  }

  String get content {
    return Intl.message(
      'Content',
      name: 'content',
      desc: 'Generic label',
    );
  }

  String get context {
    return Intl.message(
      'Context',
      name: 'context',
      desc: 'Generic label',
    );
  }

  String get description {
    return Intl.message(
      'Description',
      name: 'description',
      desc: 'Generic label',
    );
  }

  String get issueDescription {
    return Intl.message(
      'Issue description',
      name: 'issueDescription',
      desc: 'As in "Jira issue description"',
    );
  }

  String get issueComments {
    return Intl.message(
      'Issue comments',
      name: 'issueComments',
      desc: 'Jira comments label',
    );
  }

  String get newQuery {
    return Intl.message(
      'New query',
      name: 'newQuery',
      desc: 'Button label',
    );
  }

  String get newPrompt {
    return Intl.message(
      'New prompt',
      name: 'newPrompt',
      desc: 'Button label',
    );
  }

  String get cannotBeEmpty {
    return Intl.message(
      'Cannot be empty',
      name: 'cannotBeEmpty',
      desc: 'Button label',
    );
  }

  String get newStashNameHint {
    return Intl.message(
      'e.g. Get jira issues',
      name: 'newStashNameHint',
      desc: 'Button label',
    );
  }

  String jiraStatus(String status) {
    return Intl.message(
      'Jira issue status: $status',
      name: 'jiraStatus',
      desc: 'tooltip',
    );
  }

  String jiraType(String type) {
    return Intl.message(
      'Jira issue type: $type',
      name: 'jiraType',
      desc: 'tooltip',
    );
  }

  String get noDescription {
    return Intl.message(
      'No Description',
      name: 'noDescription',
      desc: 'label, "No description for this ticket"',
    );
  }

  String get after {
    return Intl.message(
      'After',
      name: 'after',
      desc: 'label, "After Dec 25"',
    );
  }

  String afterDate(String date) {
    return Intl.message(
      'After $date',
      name: 'afterDate',
      desc: 'label, "After Dec 25"',
      args: [date],
    );
  }

  String get before {
    return Intl.message(
      'Before',
      name: 'before',
      desc: 'label, "Before Jan 1"',
    );
  }

  String beforeDate(String date) {
    return Intl.message(
      'Before $date',
      name: 'beforeDate',
      desc: 'label, "Before Jan 1"',
      args: [date],
    );
  }

  String get newStashContentHint {
    return Intl.message(
      'e.g. SELECT * FROM jira.issues LIMIT 100;',
      name: 'newStashNameHint',
      desc: 'Button label',
    );
  }

  String get newStashDescriptionHint {
    return Intl.message(
      'e.g. Explain what this does',
      name: 'newStashDescriptionHint',
      desc: 'Button label',
    );
  }

  String get excessiveQueryError {
    return Intl.message(
      'Couldn\'t process this query. Try narrowing down your search with LIMIT or WHERE conditions',
      name: 'excessiveQueryError',
      desc: 'Generic label',
    );
  }

  String get email {
    return Intl.message(
      'Email',
      name: 'email',
      desc: 'Generic label',
    );
  }

  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: 'Generic label',
    );
  }

  String get logIn {
    return Intl.message(
      'Log in',
      name: 'login',
      desc: 'Generic label',
    );
  }

  String get logInWithGoogle {
    return Intl.message(
      'Log in with Google',
      name: 'logInWithGoogle',
      desc: 'Button label',
    );
  }

  String get logOut {
    return Intl.message(
      'Log out',
      name: 'logOut',
      desc: 'Generic label',
    );
  }

  String get showPassword {
    return Intl.message(
      'Show password',
      name: 'showPassword',
      desc: 'Password visibility button',
    );
  }

  String get hidePassword {
    return Intl.message(
      'Hide password',
      name: 'hidePassword',
      desc: 'Password visibility button',
    );
  }

  String get addDatasource {
    return Intl.message(
      'Add data source',
      name: 'addDatasource',
      desc: 'Database connector label',
    );
  }

  String get host {
    return Intl.message(
      'Host',
      name: 'host',
      desc: 'Database connector label',
    );
  }

  String get connectorName {
    return Intl.message(
      'Connector name',
      name: 'connectorName',
      desc: 'Database connector label',
    );
  }

  String get port {
    return Intl.message(
      'Port',
      name: 'port',
      desc: 'Database connector label',
    );
  }

  String get testConnection {
    return Intl.message(
      'Test connection',
      name: 'testConnection',
      desc: 'Database connector label',
    );
  }

  String get invalidNumber {
    return Intl.message(
      'Invalid number',
      name: 'invalidNumber',
      desc: 'Database connector validation',
    );
  }

  String get user {
    return Intl.message(
      'User',
      name: 'user',
      desc: 'Database connector label',
    );
  }

  String get database {
    return Intl.message(
      'Database',
      name: 'database',
      desc: 'Database connector label',
    );
  }
}

class LocsDelegate extends LocalizationsDelegate<L> {
  const LocsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<L> load(Locale locale) => L.load(locale);

  @override
  bool shouldReload(LocalizationsDelegate<L> old) => false;
}

// generate arb files from string resources
// flutter pub pub run intl_translation:extract_to_arb --output-dir=lib/l10n lib/locale/locales.dart

// generate code for string lookup from arb files
// locale is inferred from @@locale in arb
// flutter pub pub run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/intl_en.arb lib/l10n/intl_fr.arb lib/locale/locales.dart
