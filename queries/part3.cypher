// Query 1 — Thriller movies with average rating above 4.0
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)

WITH m,
     avg(r.rating) AS avgRating,
     count(r) AS totalRatings

WHERE avgRating > 4.0

RETURN m.title AS movie,
       round(avgRating, 2) AS averageRating,
       totalRatings

ORDER BY averageRating DESC, totalRatings DESC;


// Query 2 — Users with more than 50 five-star ratings
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating = 5

WITH u, count(DISTINCT m) AS fiveStarMovies
WHERE fiveStarMovies > 50

RETURN u.userId AS userId,
       fiveStarMovies

ORDER BY fiveStarMovies DESC;


// Query 3 — Movies highly rated by both users
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
      <-[r2:RATED]-(u2:User {userId: 2})

WHERE r1.rating >= 4
  AND r2.rating >= 4

RETURN m.title AS movie,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating

ORDER BY m.title;


// Query 4 — Genres with consistently high ratings
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(u:User)

WITH g,
     avg(r.rating) AS avgRating,
     count(r) AS totalRatings,
     count(DISTINCT m) AS ratedMovies

WHERE totalRatings >= 100

RETURN g.name AS genre,
       round(avgRating, 2) AS averageRating,
       totalRatings,
       ratedMovies

ORDER BY averageRating DESC;


// Query 5 — User-based collaborative filtering
MATCH (target:User {userId: 1})-[r1:RATED]->(common:Movie)
      <-[r2:RATED]-(similar:User)

WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND target <> similar

WITH target, similar,
     count(DISTINCT common) AS commonLikedMovies

WHERE commonLikedMovies >= 2

MATCH (similar)-[r3:RATED]->(recommended:Movie)
WHERE r3.rating >= 4
  AND NOT EXISTS {
      MATCH (target)-[:RATED]->(recommended)
  }

RETURN recommended.title AS recommendedMovie,
       count(DISTINCT similar) AS similarUsers,
       round(avg(r3.rating), 2) AS averageRating,
       max(commonLikedMovies) AS maxSharedMovies

ORDER BY similarUsers DESC, averageRating DESC
LIMIT 10;


// Query 6 — Shortest path between two users

MATCH (u1:User {userId: 1}),
      (u2:User {userId: 2})

MATCH p = shortestPath(
    (u1)-[:RATED*..6]-(u2)
)

RETURN
    p AS path,
    length(p) AS pathLength,
    [n IN nodes(p) |
        CASE
            WHEN n:User THEN 'User ' + toString(n.userId)
            WHEN n:Movie THEN n.title
        END
    ] AS pathNodes;