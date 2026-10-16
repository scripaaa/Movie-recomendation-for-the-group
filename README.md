# Movie Recommender

## UI and Tailwind CSS

The interface uses Tailwind CSS 4 via `tailwindcss-rails`. Theme colors and fonts live in
`app/assets/tailwind/application.css`. The app uses a dark theme by default, with
shared tokens for backgrounds, text, borders and accents. Native form controls
also use the dark color scheme. Views use Tailwind utilities; shared button,
input and label classes live in `ApplicationHelper`. Navigation and notifications
are shared view partials. Decorative SVG icons use `ui_icon` so stroke widths and
accessibility attributes stay consistent across screens.

Install dependencies and start the app (also builds the stylesheet):

```powershell
bundle install
ruby bin/dev
```

While editing views, run the Tailwind watcher in a second terminal:

```powershell
ruby bin/rails tailwindcss:watch
```

For a one-time build, run `ruby bin/rails tailwindcss:build`. Rails also builds
Tailwind before tests and production asset precompilation. Generated CSS in
`app/assets/builds` is ignored by Git. Tailwind is compiled locally; no browser CDN
or Node.js dependency is required.

## UI Kit screens

Authenticated UI routes include `/ratings`, `/recommendations`, `/rooms`,
`/rooms/new`, `/room` and `/rooms/:id`. The room's selection button opens
`/room/selection` or `/rooms/:id/selection`, with a return link to the same room.
The selection screen is a shell for the future shared survey. The room, invitation, recommendation and
personal rating interfaces are ready for backend integration. They do not create
records, send invitations, save ratings or calculate recommendations yet. Form
submission for actions without a backend stays on the page and reports that the action is not available. No
sample rooms, members, invitation links or recommendation results are generated.

## Movie search setup

Movie search uses the TMDB API from the Rails server. Create an API Read Access Token in your TMDB account settings, then set it in the environment before starting Rails:

```powershell
$env:TMDB_API_READ_ACCESS_TOKEN = "your-token"
bin/rails server
```

Open `/movies` while signed in to search the catalog. Keep the token out of source code and do not commit it.

Movie data and posters are provided by TMDB. This website uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.
