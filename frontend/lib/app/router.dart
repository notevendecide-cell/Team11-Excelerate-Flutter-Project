import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../ui/app_popups.dart';
import '../app/auth_controller.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/learner/learner_dashboard_screen.dart';
import '../screens/learner/learner_programs_screen.dart';
import '../screens/learner/learner_program_detail_screen.dart';
import '../screens/learner/task_detail_screen.dart';
import '../screens/learner/learner_performance_report_screen.dart';
import '../screens/mentor/mentor_dashboard_screen.dart';
import '../screens/mentor/mentor_submissions_screen.dart';
import '../screens/mentor/mentor_review_screen.dart';
import '../screens/mentor/mentor_learner_timeline_screen.dart';
import '../screens/mentor/mentor_programs_screen.dart';
import '../screens/mentor/mentor_program_overview_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_programs_screen.dart';
import '../screens/admin/admin_program_detail_screen.dart';
import '../screens/admin/admin_audit_logs_screen.dart';

class AppRouter {
  final AuthController auth;
  final ApiClient api;

  AppRouter({required this.auth, required this.api});

  late final GoRouter router = GoRouter(
    refreshListenable: auth,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(auth: auth),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(auth: auth),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsScreen(api: api),
      ),
      GoRoute(
        path: '/learner',
        builder: (context, state) => LearnerDashboardScreen(
          auth: auth,
          api: api,
          openNotifications: () async {
            await context.push('/notifications');
          },
        ),
      ),
      GoRoute(
        path: '/learner/programs',
        builder: (context, state) => LearnerProgramsScreen(
          api: api,
          openProgram: (id) => context.push('/learner/programs/$id'),
        ),
      ),
      GoRoute(
        path: '/learner/programs/:programId',
        builder: (context, state) => LearnerProgramDetailScreen(
          api: api,
          programId: state.pathParameters['programId']!,
          openTask: (taskId) => context.push('/learner/tasks/$taskId'),
        ),
      ),
      GoRoute(
        path: '/learner/tasks/:taskId',
        builder: (context, state) => TaskDetailScreen(
          api: api,
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/learner/performance',
        builder: (context, state) => LearnerPerformanceReportScreen(api: api),
      ),
      GoRoute(
        path: '/mentor',
        builder: (context, state) => MentorDashboardScreen(
          auth: auth,
          api: api,
          openNotifications: () async {
            await context.push('/notifications');
          },
        ),
      ),
      GoRoute(
        path: '/mentor/submissions',
        builder: (context, state) => MentorSubmissionsScreen(
          api: api,
          openReview: (id) => context.push('/mentor/submissions/$id/review'),
        ),
      ),
      GoRoute(
        path: '/mentor/submissions/:submissionId/review',
        builder: (context, state) => MentorReviewScreen(
          api: api,
          submissionId: state.pathParameters['submissionId']!,
        ),
      ),
      GoRoute(
        path: '/mentor/learners/:learnerId/timeline',
        builder: (context, state) => MentorLearnerTimelineScreen(
          api: api,
          learnerId: state.pathParameters['learnerId']!,
        ),
      ),
      GoRoute(
        path: '/mentor/programs',
        builder: (context, state) => MentorProgramsScreen(api: api),
      ),
      GoRoute(
        path: '/mentor/programs/:programId',
        builder: (context, state) => MentorProgramOverviewScreen(
          api: api,
          programId: state.pathParameters['programId']!,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => AdminDashboardScreen(
          auth: auth,
          api: api,
          openNotifications: () async {
            await context.push('/notifications');
          },
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => AdminUsersScreen(api: api),
      ),
      GoRoute(
        path: '/admin/programs',
        builder: (context, state) => AdminProgramsScreen(
          api: api,
          openProgram: (id) => context.push('/admin/programs/$id'),
        ),
      ),
      GoRoute(
        path: '/admin/programs/:programId',
        builder: (context, state) => AdminProgramDetailScreen(
          api: api,
          programId: state.pathParameters['programId']!,
        ),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => AdminAuditLogsScreen(api: api),
      ),
    ],
    redirect: (context, state) {
      final isInit = auth.status == AuthStatus.initializing;
      if (isInit) return null;

      final isAuthed = auth.status == AuthStatus.authenticated;
      final goingToLogin = state.matchedLocation == '/login';
      final goingToSignup = state.matchedLocation == '/signup';

      if (!isAuthed) {
        return (goingToLogin || goingToSignup) ? null : '/login';
      }

      final role = auth.user?.role;
      final home = switch (role) {
        'learner' => '/learner',
        'mentor' => '/mentor',
        'admin' => '/admin',
        _ => '/login',
      };

      if (goingToLogin) return home;

      // Prevent cross-role route access.
      if (role == 'learner' && state.matchedLocation.startsWith('/admin')) return home;
      if (role == 'learner' && state.matchedLocation.startsWith('/mentor')) return home;
      if (role == 'mentor' && state.matchedLocation.startsWith('/admin')) return home;
      if (role == 'mentor' && state.matchedLocation.startsWith('/learner')) return home;
      if (role == 'admin' && state.matchedLocation.startsWith('/learner')) return home;
      if (role == 'admin' && state.matchedLocation.startsWith('/mentor')) return home;

      return null;
    },
    errorBuilder: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnack(context, 'Navigation error');
      });
      return const Scaffold(body: Center(child: Text('Something went wrong.')));
    },
  );
}
