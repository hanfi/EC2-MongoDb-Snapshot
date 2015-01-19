# EC2-MongoDb-Snapshot
Garantee the integrity of your EC2 volume Snapshot while running MongoDb

to run on the mongoDb instance

Steps:
-----
1- blocks writing on the mongoDb
2- snapshot the EC2 instance volume attached
3- unlock the writing to mongoDb
