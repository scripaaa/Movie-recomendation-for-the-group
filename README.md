# Movie Recommender

## Movie search setup

Movie search uses the TMDB API from the Rails server. Create an API Read Access Token in your TMDB account settings, then set it in the environment before starting Rails:

```powershell
$env:TMDB_API_READ_ACCESS_TOKEN = "your-token"
bin/rails server
```

Open `/movies` while signed in to search the catalog. Keep the token out of source code and do not commit it.

Movie data and posters are provided by TMDB. This website uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.
