local function convars()
    CreateLambdaConvar( "lambdaplayers_sparta_aftertrack", "lambdasparta/aftertrack.mp3", true, false, false, "The sound file to play after Sparta Punch has been successfully used", nil, nil, { type = "Text", name = "Sparta Punch AfterTrack", category = "Weapon Utilities" } )
end

hook.Add( "LambdaOnConvarsCreated", "lambdasparta_convars", convars )