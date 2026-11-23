# NoSQL Homework 3 — MovieLens Knowledge Graph

## Project Overview

This project implements a graph-based movie recommendation system using **Neo4j AuraDB Free** and the **MovieLens 1M** dataset.

The objective is to explore graph data modeling, Cypher queries, recommendation patterns, shortest paths, and supernode detection.

The project covers:

- Graph schema design and relationship modeling.
- Importing MovieLens data into Neo4j AuraDB.
- Creating uniqueness constraints and indexes.
- Writing Cypher queries for analysis and recommendations.
- Detecting high-degree nodes (supernodes).
- Comparing graph databases with relational databases.

**Dataset:** [MovieLens 1M](https://grouplens.org/datasets/movielens/1m/)

**Database:** Neo4j AuraDB Free

**Language:** Cypher 25

**Environment:** Python (CSV conversion), VS Code, Neo4j Aura Query; Aura Graph Analytics (optional GDS)

## How to Reproduce

1. Download MovieLens 1M from the dataset source and place `movies.dat`, `users.dat`, and `ratings.dat` under `ml-1m/ml-1m/` (the nested path used in this project).
2. Run `python convert.py` to produce UTF-8 CSV files under `import/`.
3. Open Neo4j Aura Query and execute the statements in [`queries/part2_load.cypher`](queries/part2_load.cypher) in their intended order: constraints, nodes, `HAS_GENRE`, then batched `RATED` relationships. The current Cypher import uses publicly reachable CSV URLs; replace them if the hosting location changes.
4. Run the six queries in [`queries/part3.cypher`](queries/part3.cypher) and the supernode analysis in [`queries/part4_supernodes.cypher`](queries/part4_supernodes.cypher).
5. Optionally run [`queries/part5_gds.cypher`](queries/part5_gds.cypher) in a compatible Aura Graph Analytics session. The projected graphs are temporary; delete the session after collecting results.

**Scope:** All main analytical results use the first 200,000 ratings; GDS projections use smaller, explicitly constrained user samples. Screenshots in `output/` provide execution evidence. Actual runtime, cost, and performance comparisons against SQL were not benchmarked.

---

## Part 1 — Graph Schema Design

### 1.1 Graph Schema

The graph contains three node types and two relationship types.

```text
(User {userId, gender, age, occupation})
   |
   | RATED {rating, timestamp}
   v
(Movie {movieId, title, year})
   |
   | HAS_GENRE
   v
(Genre {name})
```

### 1.2 Nodes

| Node | Properties | Description |
|---|---|---|
| User | userId, gender, age, occupation | Represents a MovieLens user |
| Movie | movieId, title, year | Represents a movie |
| Genre | name | Represents a movie genre |

### 1.3 Relationships

| Relationship | Direction | Properties | Description |
|---|---|---|---|
| RATED | User → Movie | rating, timestamp | Stores a user's rating of a movie |
| HAS_GENRE | Movie → Genre | — | Connects movies with their genres |

### 1.4 Design Decisions

**Q1. Why are users, movies, and genres modeled as nodes?**

Users, movies, and genres are independent entities that participate in multiple relationships. Representing them as nodes enables efficient traversal of user preferences, movie similarities, and genre connections.

**Q2. Why is a rating modeled as a relationship instead of a separate node?**

A rating represents an interaction between one user and one movie. Storing its score and timestamp as properties of the `RATED` relationship simplifies recommendation queries and reduces the number of graph elements.

A separate `Rating` node would be more appropriate if ratings required additional relationships, detailed histories, or independent lifecycle management.

**Q3. Why are genres modeled as separate nodes instead of a list property?**

Separate `Genre` nodes allow movies to share the same genre entity. This makes genre-based traversals, recommendations, and analysis more natural.

A genre list would be simpler for basic filtering, but less convenient when genres participate in graph relationships.

---

## Part 2 — Data Preparation and Loading

### 2.1 Data Preparation

The MovieLens 1M dataset contains:

- 6,040 users.
- 3,883 movies.
- 1,000,209 ratings.

The original `.dat` files use `::` as a delimiter and Latin-1 encoding.

The `convert.py` script converts the original Latin-1 `.dat` files into UTF-8 CSV files in `import/`. For this project, ratings are limited to the first 200,000 rows during database import; the CSV conversion itself includes all 1,000,209 ratings.

### 2.2 Database Configuration

The project uses **Neo4j AuraDB Free**, avoiding the need for a locally managed Neo4j server.

Connection and APOC availability were verified successfully.

| Check | Result |
|---|---|
| AuraDB connection | Successful |
| APOC version | 2026.10.2 |
| `apoc.periodic.iterate` | Available |

### 2.3 Constraints and Indexes

Three uniqueness constraints were created before data ingestion.

| Constraint | Node | Property |
|---|---|---|
| user_id_unique | User | userId |
| movie_id_unique | Movie | movieId |
| genre_name_unique | Genre | name |

These uniqueness constraints enforce distinct values for the specified properties (when present) and create backing indexes used by `MERGE` and relationship lookup. `MERGE` is responsible for reusing existing matching nodes and relationships during repeated imports.

All three constraints were successfully verified using `SHOW CONSTRAINTS`.

Implementation: `queries/part2_load.cypher`.

### 2.5 Data Import Results

The MovieLens 1M dataset was successfully imported into Neo4j AuraDB Free using Cypher `LOAD CSV` queries with CSV files accessible via GitHub Raw URLs.

Uniqueness constraints were created before loading data. `MERGE` was used to prevent duplicate nodes and relationships during repeated executions.

The `RATED` relationships were imported in batches using `apoc.periodic.iterate` with a batch size of 1,000 and sequential execution (`parallel: false`).

Due to the resource limitations of AuraDB Free, the import was limited to the first 200,000 ratings.

| Element | Imported count |
|---|---:|
| User nodes | 6,040 |
| Movie nodes | 3,883 |
| Genre nodes | 18 |
| RATED relationships | 200,000 |
| HAS_GENRE relationships | 6,408 |
| **Total nodes** | **9,941** |
| **Total relationships** | **206,408** |

The final node and relationship counts were verified using Cypher aggregation queries. The 200,000 ratings are the first rows of the rating file, **not a random or representative sample**, so analysis results may be biased toward users appearing earlier in the source file.

## Part 3 — Cypher Queries

**Implementation:** [queries/part3.cypher](queries/part3.cypher)

This section demonstrates six Cypher queries of increasing complexity using the MovieLens knowledge graph. The queries cover filtering, aggregation, shared preferences, collaborative filtering, and shortest-path analysis.

The analysis is based on a subset of 200,000 ratings from the MovieLens 1M dataset.

### Query 1 — Thriller Movies with Average Rating Above 4.0

**Purpose:** Identify Thriller movies whose average user rating exceeds 4.0.

**Logic:** Traverse `HAS_GENRE` and `RATED` relationships, calculate the average rating and number of ratings per movie, filter results above 4.0, and sort by average rating.

**Results:**

| Movie | Average rating | Total ratings |
|---|---:|---:|
| Blackmail (1929) | 5.00 | 1 |
| The Usual Suspects (1995) | 4.56 | 342 |
| The Third Man (1949) | 4.52 | 89 |
| Rear Window (1954) | 4.49 | 198 |

**Interpretation:** A high average rating does not necessarily indicate a reliable recommendation. Blackmail has a perfect score based on only one rating, whereas The Usual Suspects has a high average supported by hundreds of ratings.

### Query 2 — Users with More Than 50 Five-Star Ratings

**Purpose:** Identify users who gave a rating of 5 to more than 50 distinct movies.

**Logic:** Filter `RATED` relationships with a rating of 5, count distinct movies per user, and return users exceeding the threshold.

**Results:**

| User ID | Five-star movies |
|---|---:|
| 549 | 402 |
| 53 | 353 |
| 1015 | 308 |
| 412 | 272 |
| 195 | 262 |

**Interpretation:** Some users are substantially more active in assigning maximum ratings. User 549 gave 402 five-star ratings, making this user an interesting candidate for further analysis of graph connectivity.

### Query 3 — Movies Highly Rated by Two Users

**Purpose:** Find movies that both User 1 and User 2 rated at least 4.

**Logic:** Match the pattern `User → Movie ← User` and filter both relationship ratings to be at least 4.

**Results:** Six movies satisfy the condition, including:

- Awakenings (1990)
- Dead Poets Society (1989)
- Driving Miss Daisy (1989)
- One Flew Over the Cuckoo's Nest (1975)
- Saving Private Ryan (1998)
- To Kill a Mockingbird (1962)

**Interpretation:** The shared movie connections demonstrate overlapping user preferences. Such patterns form the basis for graph-based collaborative recommendation systems.

### Query 4 — Genres with High Average Ratings

**Purpose:** Compare movie genres using their average rating, total number of ratings, and number of rated movies.

**Logic:** Traverse `User → Movie → Genre`, aggregate rating information by genre, and exclude genres with fewer than 100 ratings.

**Results:**

| Genre | Average rating | Total ratings |
|---|---:|---:|
| Film-Noir | 4.07 | 3,523 |
| Documentary | 3.93 | 1,562 |
| War | 3.87 | 13,458 |
| Drama | 3.74 | 70,945 |
| Animation | 3.70 | 9,159 |
| Crime | 3.67 | 15,496 |

**Interpretation:** Film-Noir has the highest average rating among the displayed genres, while Drama has substantially more ratings. Average rating and rating volume measure different aspects of user preferences. Ratings of movies belonging to multiple genres contribute to each applicable genre.

### Query 5 — User-Based Collaborative Filtering

**Purpose:** Recommend movies to User 1 based on other users with similar preferences.

**Logic:** Identify users who share at least two highly rated movies with the target user, find additional movies those users rated highly, and exclude movies already rated by the target user. Rank candidates by the number of similar users supporting each recommendation.

**Results:**

| Recommended movie | Similar users | Average rating |
|---|---:|---:|
| American Beauty (1999) | 526 | 4.68 |
| Star Wars: Episode V — The Empire Strikes Back (1980) | 498 | 4.58 |
| The Silence of the Lambs (1991) | 438 | 4.56 |
| Raiders of the Lost Ark (1981) | 429 | 4.65 |
| The Matrix (1999) | 425 | 4.67 |

**Interpretation:** The graph supports collaborative filtering by identifying shared preferences through multi-hop relationships. The approach generates recommendations without training a machine-learning model, although popular movies may receive disproportionate support.

### Query 6 — Shortest Path Between Two Users

**Purpose:** Find the shortest connection between User 1 and User 2 through movies they have rated.

**Logic:** Search for the shortest path using undirected traversal over `RATED` relationships, allowing at most six hops.

**Results:** The query returned a path containing three nodes and two `RATED` relationships, with a path length of 2.

**Interpretation:**

- **Path length 2:** Two users rated the same movie.
- **Path length 4:** Two users are connected through one intermediate user and two movies.
- **Path length 6:** Two users are connected through two intermediate users and three movies.

A hop represents traversal of one relationship. The shortest path is measured in relationships, not in the number of movies or users alone.

The shortest path is calculated using graph connectivity, regardless of the actual rating values. Therefore, two users connected through a movie do not necessarily have similar preferences.

### Shortest Path Interpretation

**1. What does path length mean in this graph?**

Path length represents the number of relationships (hops) traversed between two users. In our graph, users are connected to movies through `RATED` relationships. Therefore, the shortest path measures how many relationships are needed to connect two users through movies they have rated.

**2. What does a path length of 2 mean?**

A path length of 2 indicates that two users rated at least one common movie.

Example:

`User 1 → Movie A ← User 2`

The query between User 1 and User 2 returned a shortest path length of 2, demonstrating that they share a rated movie.

**3. How should paths of length 4 and 6 be interpreted?**

A path length of 4 means two users are connected through one intermediate user and two movies.

`User 1 → Movie A ← User 3 → Movie B ← User 2`

A path length of 6 means two users are connected through two intermediate users and three movies.

`User 1 → Movie A ← User 3 → Movie B ← User 4 → Movie C ← User 2`

Longer paths indicate more indirect connections between users. However, path length alone does not measure preference similarity because `RATED` relationships may represent positive or negative ratings.

### Part 3 Conclusion

The six queries demonstrate how Cypher expresses relationships directly through graph patterns. Simple aggregation queries resemble SQL operations, while shared-preference, recommendation, and shortest-path queries benefit from the graph model's explicit relationships. All results reflect the imported subset of 200,000 ratings and do not represent the entire MovieLens 1M dataset.

## Part 4 — Supernode Detection

**Implementation:** [queries/part4_supernodes.cypher](queries/part4_supernodes.cypher)


### 4.1 Identifying Supernodes

A supernode is a graph node with an unusually high degree, meaning it is connected to significantly more relationships than typical nodes.

To identify supernodes, we calculated the total number of relationships connected to each node and sorted the results in descending order.

The highest-degree nodes observed include:

| Node | Type | Degree |
|---|---|---:|
| Drama | Genre | 1,603 |
| User 1181 | User | 1,521 |
| User 889 | User | 1,518 |
| User 1150 | User | 1,302 |
| User 1015 | User | 1,286 |
| User 424 | User | 1,226 |
| Comedy | Genre | 1,200 |

Both highly active users and popular genres are potential supernodes. The table lists the seven records visible in the saved result, rather than claiming to reproduce all ten rows.

### 4.2 Genre Supernode Analysis

Genre nodes were analyzed separately by counting the movies connected through `HAS_GENRE` relationships.

The most connected genres were:

| Genre | Connected movies |
|---|---:|
| Drama | 1,603 |
| Comedy | 1,200 |
| Action | 503 |
| Thriller | 492 |
| Romance | 471 |

Drama and Comedy have substantially more connections than most other genres.

This confirms that genre nodes can also behave as supernodes because thousands of movies share the same genre entities.

### 4.3 Why Do Supernodes Affect Query Performance?

Indexes help Neo4j locate a node efficiently using indexed properties such as `Genre.name` or `User.userId`.

However, once a high-degree node has been found, Neo4j may still need to traverse a large number of its relationships.

For example, traversing from the Drama genre to connected movies can produce up to 1,603 movie matches before any subsequent filtering.

When a query continues from those movies to their users, the number of intermediate records may increase significantly. This phenomenon is known as *fan-out*.

Therefore, node lookup indexes do not eliminate the computational cost of traversing large numbers of relationships.

### 4.4 Recommended Optimization Strategy

For this dataset, the recommended strategy is to minimize unnecessary traversal through high-degree genre nodes.

Instead of beginning a recommendation query from a broad genre such as Drama, queries should start from a selective indexed node, such as a specific user or movie, and expand only through the relationships required by the task.

Additional optimizations include applying selective filters early, restricting relationship types and traversal depth, and aggregating intermediate results before further graph expansion when appropriate.

For frequently executed genre-based analytical queries, a denormalized genre property on Movie nodes could also be considered as a supplementary representation. This may simplify certain filters while preserving Genre nodes for graph exploration.

These strategies reduce unnecessary graph expansion without changing the existing recommendation model.

### 4.5 Conclusion

Supernode detection identified two main sources of high connectivity in the MovieLens graph: popular genres and highly active users.

Drama had the highest observed degree (1,603), followed by User 1181 (1,521).

The analysis demonstrates that graph query performance depends not only on indexes but also on graph topology, node degree, and the number of relationships traversed during query execution.

## Part 5 — Graph Data Science (Optional)

**Implementation:** [queries/part5_gds.cypher](queries/part5_gds.cypher)

The optional GDS experiments use **in-memory projections**, not persistent `CO_RATED` or `SIMILAR` relationships in the source database.

### 5.1 PageRank — Movie Influence Analysis

PageRank was executed on an undirected movie similarity graph containing 218 movie nodes and 6,000 projected relationship entries, representing 3,000 movie pairs.

The projection was constructed from highly rated movies shared by the first 20 users, with a maximum of 3,000 movie pairs.

**Key findings:**

| Movie | PageRank score |
|---|---:|
| Star Wars: Episode VI — Return of the Jedi (1983) | 4.3405 |
| Braveheart (1995) | 4.1242 |
| Jurassic Park (1993) | 4.1152 |
| Saving Private Ryan (1998) | 3.6586 |
| Schindler's List (1993) | 3.6127 |

**Interpretation:** A high PageRank indicates that a movie occupies an influential position within the projected network of shared positive ratings. Unlike a simple popularity count, PageRank considers the connectivity of neighboring movies.

These scores are not average user ratings. Since the projection uses a restricted sample and unweighted PageRank, the findings demonstrate the algorithm rather than provide a representative ranking of the complete MovieLens dataset.

### 5.2 Louvain — User Community Detection

**Purpose:** Find user communities whose members have relatively strong connections based on shared positively rated movies.

**Methodology:** We built an undirected `userSimilarity` projection from users with IDs up to 100. Two users are connected when they rated at least two movies at 4 or above; the relationship `weight` counts their shared highly rated movies. The projection contains **100 users and 6,000 relationship entries** (3,000 undirected user pairs). Weighted Louvain was executed with `relationshipWeightProperty: 'weight'`.

**Community results:**

| Community ID | Members | Share of sample |
|---|---:|---:|
| 1 | 34 | 34% |
| 16 | 28 | 28% |
| 12 | 17 | 17% |
| 15 | 15 | 15% |
| 59 | 6 | 6% |
| **Total** | **100** | **100%** |

**Modularity:** `0.0769`. This relatively low positive value suggests weak separation between the detected communities in this dense projection. The community labels are algorithm-generated identifiers, not genre categories.

**Genre interpretation:** For each user community, positively rated movies (`rating >= 4`) were joined to their `Genre` nodes. A multi-genre movie contributes to each of its genres. The saved results explicitly establish these two examples:

| Community | Most positively rated genres (count) |
|---|---|
| 1 | Action (1,223), Drama (1,043), Comedy (894) |
| 12 | Comedy (735), Romance (352), Drama (327) |

Community 1 shows a larger count of positive ratings for Action, while Community 12 shows more positive ratings for Comedy. These counts are not normalized for group size or genre frequency and should not be used to assign definitive audience personas. The query computes top three genres for **all five** communities; only the two communities visible in the recorded screenshot are transcribed here.

**Discussion:** The communities overlap in their genre interests, and the low modularity warns against presenting them as strongly separated taste segments. The 100-user and 3,000-pair caps further limit generalization.

### 5.3 Dijkstra — Shortest Paths Between Users

**Purpose:** Analyze the shortest paths between users in the projected `userSimilarity` graph.

**Methodology:** Dijkstra's algorithm was executed on an undirected graph containing 100 users and 3,000 unique similarity relationships. All relationships were treated as having a cost of 1, so the algorithm minimized the number of hops rather than a weighted similarity distance.

**Results:**

| Source user | Target user | Path | Hops |
|---|---|---|---:|
| 1 | 53 | 1 → 53 | 1 |
| 1 | 95 | 1 → 95 | 1 |
| 5 | 82 | 5 → 82 | 1 |
| 53 | 58 | 53 → 58 | 1 |

All four selected pairs were reachable.

- Average path length: **1.0 hops**
- Minimum path length: **1 hop**
- Maximum path length: **1 hop**

**Interpretation:** All tested user pairs have direct similarity relationships. This reflects the relatively dense structure of the projected graph.

**Small-world hypothesis:** The results are consistent with short distances between users, but they do not establish the six-degrees-of-separation hypothesis. Only four selected pairs were analyzed, and the graph contains a limited sample of 100 users.

The short paths may also be influenced by the projection strategy, which retained the 3,000 pairs with the highest shared-positive-movie counts. In this unweighted Dijkstra experiment, a direct `SIMILAR` edge has cost 1 regardless of its `weight`; that cost does not measure preference similarity.

**Conclusion:** Dijkstra successfully identified shortest paths within the similarity graph. A larger and more representative graph, together with broader shortest-path analysis, would be needed to assess the network's overall small-world properties.

## Part 6 — Analysis and Conclusions

### 6.1 Graph Databases vs Relational Databases

Graph databases and relational databases can represent the same MovieLens dataset, but they organize relationships differently.

In a relational database, users, movies, genres, and ratings would be stored in separate tables connected through primary and foreign keys. Queries involving multiple entities would typically require SQL JOIN operations.

In Neo4j, these relationships are explicitly represented as graph edges, making connected data easier to explore using Cypher patterns.

**Example: Query 3 — Movies Highly Rated by Two Users**

The Cypher implementation identifies movies that both User 1 and User 2 rated at least 4.

```cypher
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
      <-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title;
```

An equivalent SQL query would be:

```sql
SELECT DISTINCT m.title
FROM movies m
JOIN ratings r1
    ON m.movie_id = r1.movie_id
JOIN ratings r2
    ON m.movie_id = r2.movie_id
WHERE r1.user_id = 1
  AND r2.user_id = 2
  AND r1.rating >= 4
  AND r2.rating >= 4;
```

Both implementations can efficiently solve this problem when the underlying database is appropriately indexed.

However, more complex graph operations provide a clearer distinction.

**Query 5 — Collaborative Filtering:** Neo4j expresses recommendations through multi-hop patterns connecting users, shared movies, similar users, and candidate movies. The SQL equivalent requires multiple joins, aggregation, and exclusion of previously rated movies.

**Query 6 — Shortest Path:** Neo4j provides graph traversal capabilities for finding paths between users. SQL can also support graph traversal through recursive common table expressions, but implementing shortest-path searches can require substantially more complex query logic.

Therefore, the primary benefit of Neo4j in this project is its natural representation of relationships and its expressive graph traversal capabilities, rather than a guarantee of better performance for every query.

### 6.2 Where Relational Databases Perform Better

Relational databases may be more suitable for several types of operations in the MovieLens dataset.

**Large-scale aggregations:** Calculating average ratings, counting user interactions, or generating overall statistics can be efficiently implemented using SQL aggregation functions such as `AVG`, `COUNT`, and `GROUP BY`.

For example, Query 4, which calculates average ratings by genre, is also a natural relational analytics task.

**Reporting and business intelligence:** Relational databases integrate well with traditional reporting tools and analytical workflows. Structured reports, dashboards, and tabular summaries can often be produced more conveniently using SQL.

**Bulk data processing and export:** The MovieLens dataset originates from structured files. Relational systems are well suited to bulk loading, filtering, transforming, and exporting large tabular datasets.

**Data integrity and structured transactions:** Relational databases provide mature mechanisms for enforcing relationships through primary keys, foreign keys, and transactional constraints.

Neo4j also supports transactions, indexes, and constraints, but these capabilities alone do not make a graph database the best choice for every workload.

The conclusion is that relational databases are generally strong candidates for structured reporting and aggregations, whereas graph databases are particularly useful when relationships and traversal patterns are central to the application.

### 6.3 Graph Schema Improvements

The current graph contains three node types (`User`, `Movie`, `Genre`) and two relationship types (`RATED`, `HAS_GENRE`).

The following optimizations could improve specific queries.

**Improvement 1 — Optimize Query 1: Thriller Movies with High Ratings**

Query 1 traverses from a genre to its movies and then aggregates incoming rating relationships.

One possible optimization is to maintain derived statistics on Movie nodes, such as:

- `averageRating`
- `ratingCount`

These properties could be periodically recalculated when rating data changes.

The query could then use the stored statistics instead of recalculating averages over all `RATED` relationships on every execution.

This approach improves repeated read-heavy analytical queries but introduces additional storage and consistency requirements.

**Improvement 2 — Optimize Query 5: Collaborative Filtering**

Query 5 discovers similar users dynamically by traversing common movies and counting shared positive ratings.

For larger graphs, this process can generate substantial intermediate results.

A possible improvement is to introduce precomputed relationships:

`(User)-[:SIMILAR {score, sharedMovies}]->(User)`

These relationships would represent user similarity calculated from shared preferences.

Recommendation queries could then directly explore the most similar users instead of recalculating similarities during every request.

This would reduce repeated graph traversal work, although similarity relationships would need to be updated when new ratings are added.

**Improvement 3 — Optimize Query 6: Shortest Path**

Query 6 searches for connections through `RATED` relationships.

Restricting traversals to relevant relationship types, limiting maximum path length, and starting from users identified through indexed properties can help control query expansion.

In addition, a derived user-similarity graph could reduce the number of intermediate movie nodes for certain user-to-user path analyses.

However, this optimization changes the meaning of the path: a `SIMILAR` relationship represents derived similarity rather than an individual movie rating.

### 6.4 Overall Project Conclusions

The MovieLens knowledge graph was successfully implemented using Neo4j AuraDB Free.

The final imported dataset contains:

| Element | Count |
|---|---:|
| User nodes | 6,040 |
| Movie nodes | 3,883 |
| Genre nodes | 18 |
| RATED relationships | 200,000 |
| HAS_GENRE relationships | 6,408 |

Six Cypher queries demonstrated filtering, aggregation, shared movie preferences, collaborative filtering, and shortest-path search.

Supernode analysis identified highly connected entities, including the Drama genre with 1,603 relationships and User 1181 with 1,521 relationships. This demonstrated the impact of graph topology on traversal complexity.

Additional Graph Data Science experiments included PageRank, Louvain community detection, and Dijkstra shortest-path analysis.

PageRank identified structurally influential movies in a limited similarity graph. Louvain identified five user communities with modularity of 0.0769, indicating relatively weak separation between communities. Dijkstra found direct paths for four selected user pairs, with an average path length of 1.0.

These GDS experiments used restricted projections and should not be interpreted as representative measurements of the complete MovieLens dataset.

**Final conclusion:** Graph databases are particularly valuable when applications depend on exploring interconnected entities, discovering relationships, generating recommendations, and finding paths. Relational databases remain effective for structured data storage, large-scale aggregation, and reporting.

The most suitable database model depends on the query workload, data structure, scalability requirements, and expected access patterns rather than on the assumption that one database technology is universally superior.
