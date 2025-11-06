repo = RebacRepo.new

# Demo: group marketing contains alice
repo.write(subject: "group", id: "marketing", relation: "member", actor: "user", actor_id: "alice")

# Folder Q4 owned by marketing
repo.write(subject: "folder", id: "Q4", relation: "owner", actor: "group", actor_id: "marketing")

# doc 123 is in folder Q4
repo.write(subject: "doc", id: "123", relation: "parent", actor: "folder", actor_id: "Q4")

puts "Seeded demo tuples."
