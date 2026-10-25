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

## User flows

Signed-in users can search TMDB, open movie details, and save or update scores
from 1 to 10. Saved ratings appear in `/ratings` and the profile. Personal
recommendations at `/recommendations` use genre preferences, genre/runtime filters,
and an option to exclude rated movies.

Users can create rooms at `/rooms/new`, copy a signed invitation link, and share
it with a friend. The friend signs in or registers, returns to the invitation,
and explicitly joins. `/rooms` and the profile show the user's real rooms.
Only room members can open a room or view and generate its shared selection.

Submitting a room's selection form uses every member's ratings with equal weight
per person. The filters and up to 12 results are saved in the room, so all members
can open the same selection at `/rooms/:id/selection`. Reading a saved selection
does not call TMDB. Generate it again after ratings or membership change.
`/room` and `/room/selection` redirect to the user's newest room, or to `/rooms`
when they have no rooms. No sample records or fake results are generated.

The room owner can start a quiz from the saved selection. Everyone present at
the start sees the same movie and votes No, Not sure, or Yes once per round.
Unanimous Yes selects the film. The owner can finish early and select the film
with the most Yes votes across completed rounds; ties favor the earlier film.
No votes lower genre priorities only in that room and reorder subsequent cards
and future room recommendations. Personal ratings are unchanged. Quiz pages
automatically refresh after votes. See the [quiz rules](docs/quiz.ru.md).

Apply migrations with `ruby bin/rails db:migrate`, then run `ruby bin/dev`.
See the [two-account walkthrough](docs/happy-path.ru.md) and
[recommendation algorithm](docs/recommendations.ru.md).

## Movie search setup

Movie search uses the TMDB API from the Rails server. Create an API Read Access Token in your TMDB account settings, then set it in the environment before starting Rails:

```powershell
$env:TMDB_API_READ_ACCESS_TOKEN = "your-token"
bin/rails server
```

Open `/movies` while signed in to search the catalog. Keep the token out of source code and do not commit it.

Movie data and posters are provided by TMDB. This website uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.
