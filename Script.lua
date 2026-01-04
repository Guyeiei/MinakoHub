local AllowedUsers = {
    [7687155911] = "KazumiNaoki002",
    [7687172761] = "KazumiNaoki003",
    [10247634512] = "Minako_Blessed",
    [0] = "NewUser2", -- เมื่อได้ไอดีใหม่มา ให้เอามาแก้แทนเลข 0 ตรงนี้
}

local player = game:GetService("Players").LocalPlayer

if not AllowedUsers[player.UserId] then
    player:Kick("🚫 Access Denied! Your ID: " .. player.UserId .. " is not Whitelisted.")
    return 
end

print("✅ Welcome: " .. AllowedUsers[player.UserId])

local Games = {
    [110483372589393] = "https://raw.githubusercontent.com/Guyeiei/MinakoHub/refs/heads/main/AnimeClestialX",
}

local placeId = game.PlaceId
if Games[placeId] then
    loadstring(game:HttpGet(Games[placeId], true))()
else
    print("ไม่พบสคริปต์สำหรับแมพนี้ ID: " .. placeId)
end
