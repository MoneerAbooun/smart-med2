# Feature-Based Structure

## Folder Structure

```text
lib/
  app/
  core/
  features/
    auth/
      auth.dart
      data/
        repositories/
      presentation/
        pages/
    home/
      presentation/
    interactions/
      interactions.dart
      data/
        repositories/
      domain/
        models/
      presentation/
        pages/
        widgets/
    medications/
      medications.dart
      data/
        repositories/
      domain/
        models/
      presentation/
        pages/
        widgets/
    profile/
      profile.dart
      data/
        repositories/
      domain/
        models/
      presentation/
        pages/
    medicine_search/
      medicine_search.dart
      data/
        repositories/
        services/
      domain/
        models/
      presentation/
        pages/
    settings/
      presentation/
```

## File Organization

- Keep app-wide setup in `lib/app` and reusable infrastructure in `lib/core`.
- Keep each product area inside `lib/features/<feature_name>`.
- Use `data/repositories` for Firebase, API, and persistence code.
- Use `domain/models` for feature models that the UI and repositories share.
- Use `presentation/pages` for full screens and `presentation/widgets` for feature-local UI pieces.
- Expose a small public API with `features/<feature>/<feature>.dart` so other features can import the feature cleanly.

## Example Feature

`auth` is now the simplest example feature:

```text
features/auth/
  auth.dart
  data/
    repositories/
      auth_repository.dart
      auth_user_flow_repository.dart
  presentation/
    pages/
      login_page.dart
      signup_page.dart
```

This pattern scales well to `profile`, `medications`, `interactions`, and `medicine_search` because each feature keeps its own models, repositories, screens, and widgets together.
