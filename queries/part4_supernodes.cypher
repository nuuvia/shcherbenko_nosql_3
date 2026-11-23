// Part 4 — Query 1: Top 10 nodes by degree
MATCH (n)

WITH n, COUNT { (n)--() } AS degree

RETURN
    labels(n) AS nodeType,
    CASE
        WHEN n:User THEN 'User ' + toString(n.userId)
        WHEN n:Movie THEN n.title
        WHEN n:Genre THEN n.name
    END AS nodeName,
    degree

ORDER BY degree DESC
LIMIT 10;

// Part 4 — Query 2: Genre nodes by degree

MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)

RETURN
    g.name AS genre,
    count(m) AS connectedMovies

ORDER BY connectedMovies DESC;

