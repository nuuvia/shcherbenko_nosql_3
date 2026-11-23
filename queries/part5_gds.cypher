// Part 5.1 — Project movie similarity graph

MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)

WHERE u.userId <= 20
  AND r1.rating >= 4
  AND r2.rating >= 4
  AND m1.movieId < m2.movieId

WITH m1, m2, count(DISTINCT u) AS weight
ORDER BY weight DESC
LIMIT 3000

WITH gds.graph.project(
    'movieGraph',
    m1,
    m2,
    {
        relationshipType: 'CO_RATED',
        relationshipProperties: {weight: toFloat(weight)}
    },
    {
        sessionId: '0d5ae1fd-bad2491c',
        undirectedRelationshipTypes: ['CO_RATED']
    }
) AS graph

RETURN
    graph.graphName AS graphName,
    graph.nodeCount AS nodeCount,
    graph.relationshipCount AS relationshipCount;


// Part 5.1 — PageRank on movie similarity graph

CALL gds.pageRank.stream('movieGraph', {
    maxIterations: 20,
    dampingFactor: 0.85
})
YIELD nodeId, score

RETURN
    gds.util.asNode(nodeId).title AS movie,
    round(score, 4) AS pageRankScore

ORDER BY pageRankScore DESC
LIMIT 10;

// Part 5.2 — Project user similarity graph

MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)

WHERE u1.userId <= 100
  AND u2.userId <= 100
  AND u1.userId < u2.userId
  AND r1.rating >= 4
  AND r2.rating >= 4

WITH u1, u2, count(DISTINCT m) AS weight

WHERE weight >= 2

ORDER BY weight DESC
LIMIT 3000

WITH gds.graph.project(
    'userSimilarity',
    u1,
    u2,
    {
        relationshipType: 'SIMILAR',
        relationshipProperties: {
            weight: toFloat(weight)
        }
    },
    {
        sessionId: '0d5ae1fd-bad2491c',
        undirectedRelationshipTypes: ['SIMILAR']
    }
) AS graph

RETURN
    graph.graphName AS graphName,
    graph.nodeCount AS nodeCount,
    graph.relationshipCount AS relationshipCount;

// Part 5.2 — Louvain Community Detection

CALL gds.louvain.stream('userSimilarity', {
    relationshipWeightProperty: 'weight',
    maxIterations: 10,
    maxLevels: 10
})
YIELD nodeId, communityId

RETURN
    communityId,
    count(nodeId) AS members,
    collect(gds.util.asNode(nodeId).userId)[0..10] AS sampleUsers

ORDER BY members DESC
LIMIT 10;


// Part 5.2 — Louvain modularity statistics

CALL gds.louvain.stats('userSimilarity', {
    relationshipWeightProperty: 'weight',
    maxIterations: 10,
    maxLevels: 10
})
YIELD communityCount, modularity, communityDistribution

RETURN communityCount,
       round(modularity, 4) AS modularity,
       communityDistribution;

// Part 5.2 — Top 3 genres per community

CALL gds.louvain.stream('userSimilarity', {
    relationshipWeightProperty: 'weight',
    maxIterations: 10,
    maxLevels: 10
})
YIELD nodeId, communityId

WITH communityId,
     gds.util.asNode(nodeId) AS user

MATCH (user)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4

WITH communityId,
     g.name AS genre,
     count(r) AS positiveRatings

ORDER BY communityId, positiveRatings DESC, genre

WITH communityId,
     collect({
         genre: genre,
         positiveRatings: positiveRatings
     })[0..3] AS topGenres

RETURN communityId, topGenres
ORDER BY communityId;

// Part 5.3 — Dijkstra shortest path

MATCH (source:User {userId: 1}),
      (target:User {userId: 53})

CALL gds.shortestPath.dijkstra.stream(
    'userSimilarity',
    {
        sourceNode: source,
        targetNode: target
    }
)
YIELD totalCost, nodeIds

RETURN
    totalCost,
    size(nodeIds) - 1 AS hops,
    [nodeId IN nodeIds |
        gds.util.asNode(nodeId).userId
    ] AS userPath;

// Part 5.3 — Dijkstra: multiple user pairs

UNWIND [
    {sourceId: 1, targetId: 53},
    {sourceId: 1, targetId: 95},
    {sourceId: 53, targetId: 58},
    {sourceId: 5, targetId: 82}
] AS pair

MATCH (source:User {userId: pair.sourceId})
MATCH (target:User {userId: pair.targetId})

CALL gds.shortestPath.dijkstra.stream(
    'userSimilarity',
    {
        sourceNode: source,
        targetNode: target
    }
)
YIELD totalCost, nodeIds

RETURN
    pair.sourceId AS sourceUser,
    pair.targetId AS targetUser,
    size(nodeIds) - 1 AS hops,
    totalCost,
    [nodeId IN nodeIds |
        gds.util.asNode(nodeId).userId
    ] AS userPath

ORDER BY sourceUser, targetUser;

