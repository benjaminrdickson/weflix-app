# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)


user = User.create!([
  {name: "Benjamin Dickson", email: "ben@gmail.com", username: "bjammin", image_url: "https://media-exp1.licdn.com/dms/image/C4D03AQF6heRxrwe1PQ/profile-displayphoto-shrink_800_800/0/1517018346471?e=1629936000&v=beta&t=jVdBqVrHI4VGXliRasn2zxy20ucXGNHAeHD84xbNELk", password: "password"},

  {name: "Megan Kozelek", email: "megan@gmail.com", username: "mkd", image_url: "https://media-exp1.licdn.com/dms/image/C4D03AQGt8kPLBZFntA/profile-displayphoto-shrink_800_800/0/1600906683623?e=1629936000&v=beta&t=qcBr8Plb9PZo3yjhIuBqErK41LsmP0muZmU3zzDOIv4", password: "password"},

  {name: "Mackenzie", email: "mackenzie@gmail.com", username: "mack", image_url: "https://media-exp1.licdn.com/dms/image/C4D03AQGt8kPLBZFntA/profile-displayphoto-shrink_800_800/0/1600906683623?e=1629936000&v=beta&t=qcBr8Plb9PZo3yjhIuBqErK41LsmP0muZmU3zzDOIv4", password: "password"},

  {name: "David", email: "david@gmail.com", username: "dvd", image_url: "https://media-exp1.licdn.com/dms/image/C4D03AQGt8kPLBZFntA/profile-displayphoto-shrink_800_800/0/1600906683623?e=1629936000&v=beta&t=qcBr8Plb9PZo3yjhIuBqErK41LsmP0muZmU3zzDOIv4", password: "password"}
])




relationship = Relationship.create!([
  {sender_id: 1, recipient_id: 2, confirmation: true},
  {sender_id: 3, recipient_id: 4, confirmation: true}
])


favorites = Favorite.create!([
  {relationship_id: 1, api_movie_id: 996},
  {relationship_id: 2, api_movie_id: 995},
  {relationship_id: 1, api_movie_id: 872} 
])

likes = Like.create!([
  {user_id: 1, api_movie_id: 996},
  {user_id: 2, api_movie_id: 996},
  {user_id: 3, api_movie_id: 995},
  {user_id: 4, api_movie_id: 995} 
])




