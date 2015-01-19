# EC2-MongoDb-Snapshot
Garantee the integrity of your EC2 volume Snapshot while running MongoDb

to run on the mongoDb instance

Steps:
-----
* blocks writing on the mongoDb
* snapshot the EC2 instance volume attached
* unlock the writing to mongoDb
