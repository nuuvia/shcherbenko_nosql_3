//MERGE protects against the re-creation of entities, while constraints provide an additional guarantee of key uniqueness.

CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User)
REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie)
REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name_unique IF NOT EXISTS
FOR (g:Genre)
REQUIRE g.name IS UNIQUE;

//Load Data

LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/movies.csv'
AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year = toInteger(
        substring(row.title, size(row.title) - 5, 4)
    );

LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/users.csv'
AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);


LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/movies.csv'
AS row
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName});


LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/movies.csv'
AS row
MATCH (m:Movie {movieId: toInteger(row.movieId)})
UNWIND split(row.genres, '|') AS genreName
MATCH (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);


CALL apoc.periodic.iterate(
  "
  LOAD CSV WITH HEADERS FROM
  'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/ratings.csv'
  AS row
  WITH row
  LIMIT 20000
  RETURN row
  ",
  "
  MATCH (u:User {userId: toInteger(row.userId)})
  MATCH (m:Movie {movieId: toInteger(row.movieId)})
  MERGE (u)-[r:RATED]->(m)
  SET r.rating = toInteger(row.rating),
      r.timestamp = toInteger(row.timestamp)
  ",
  {batchSize: 1000, parallel: false}
)
YIELD batches, total, failedBatches, errorMessages
RETURN batches, total, failedBatches, errorMessages;

CALL apoc.periodic.iterate(
  "
  LOAD CSV WITH HEADERS FROM
  'https://raw.githubusercontent.com/BorysZhyhalo/Zhyhalo_nosql_3/main/import/ratings.csv'
  AS row
  WITH row
  LIMIT 200000
  RETURN row
  ",
  "
  MATCH (u:User {userId: toInteger(row.userId)})
  MATCH (m:Movie {movieId: toInteger(row.movieId)})
  MERGE (u)-[r:RATED]->(m)
  SET r.rating = toInteger(row.rating),
      r.timestamp = toInteger(row.timestamp)
  ",
  {batchSize: 1000, parallel: false}
)
YIELD batches, total, failedBatches, errorMessages
RETURN batches, total, failedBatches, errorMessages;