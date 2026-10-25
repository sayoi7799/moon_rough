///|
/// The D2 source of the example diagram in the README.
pub let source : String =
  #|direction: right
  #|
  #|user: User {shape: person}
  #|cdn: CDN {shape: cloud}
  #|lb: Load balancer {shape: diamond}
  #|backend: Backend {
  #|  api: API
  #|  worker: Worker {shape: hexagon}
  #|  api -> worker: job
  #|}
  #|db: Database {shape: cylinder}
  #|cache: Cache {shape: queue}
  #|
  #|user -> cdn: static
  #|user -> lb: request
  #|lb -> backend.api
  #|backend.api -> db: query {target-arrowhead.shape: diamond}
  #|backend.api -> cache: {style.stroke-dash: 4}
  #|backend.worker -> db: write {target-arrowhead.shape: cf-many}
