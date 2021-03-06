module Api
  include HTTParty

  def client
    client = GooglePlaces::Client.new(ENV["GOOGLE_PLACES_API_KEY"])
  end

  #args options {longitude: float, latitude: float, city_or_zip: string, neighborhood: string}
  def get_places_info(args)
    if args[:latitude] && args[:longitude]
      restaurants = get_restaurants_by_geolocation(args[:latitude], args[:longitude])
    elsif args[:neighborhood] && args[:city_or_zip]
      restaurants = get_restaurants_by_city_neighborhood(args[:neighborhood], args[:city_or_zip])
    elsif args[:city_or_zip]
      restaurants = get_restaurants_by_city_or_zip(args[:city_or_zip])
    end
    restaurants.map do |restaurant|
      {google_id: restaurant.place_id, name: restaurant.name, rating: restaurant.rating}
    end
  end

  def get_restaurants_by_city_or_zip(city_or_zip)
    client.spots_by_query("Restaurants near #{city_or_zip}")
  end

  def get_restaurants_by_geolocation(latitude, longitude)
    client.spots(latitude, longitude, :types => ['restaurant','food'])
  end

  def get_restaurants_by_city_neighborhood(neighborhood, city)
    client.spots_by_query("Restaurants in #{neighborhood} neighborhood #{city}")
  end

  def get_photo_references(google_id)
    place = HTTParty.get("https://maps.googleapis.com/maps/api/place/details/json?placeid=#{google_id}&key=#{ENV['GOOGLE_PLACES_API_KEY']}")
    if place['result'] && place['result']['photos']
      place['result']['photos'].map do |photo|
        photo['photo_reference']
      end
    else
      []
    end 
  end

  def fetch_photo_urls(google_id)
    photo_references = get_photo_references(google_id)
    food_photo_urls = []
    if photo_references != []
      photo_references.each do |p_r|
        photo_url = HTTParty.get("https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=#{p_r}&key=#{ENV['GOOGLE_PLACES_API_KEY']}").request.last_uri.to_s
        if (HTTParty.get("http://api.foodai.org/v1/classify?image_url=#{photo_url}&num_tag=1")['tags']) && (HTTParty.get("http://api.foodai.org/v1/classify?image_url=#{photo_url}&num_tag=1")['tags'][0]) && (HTTParty.get("http://api.foodai.org/v1/classify?image_url=#{photo_url}&num_tag=1")['tags'][0][0])
          pic_description = HTTParty.get("http://api.foodai.org/v1/classify?image_url=#{photo_url}&num_tag=1")['tags'][0][0]
          if pic_description != "Non_Food"
            food_photo_urls << photo_url
          end
        end
      end
      food_photo_urls
    end
  end
end
