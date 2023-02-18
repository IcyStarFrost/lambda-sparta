local CurTime = CurTime
local sound_Play = sound.Play
local ipairs = ipairs
local util_Effect = util.Effect
local VectorRand = VectorRand
local killdir = GetConVar( "lambdaplayers_voice_killdir" )
local random = math.random
local abs = math.abs
local bit_bor = bit.bor

if SERVER then
    util.AddNetworkString( "lambdaplayers_sparta_decal" )
    util.AddNetworkString( "lambdaplayers_sparta_smoke" )

elseif CLIENT then
    local util_DecalMaterial = util.DecalMaterial
    local Material = Material
    local Trace = util.TraceLine
    local util_DecalEx = util.DecalEx
    local tracetable = {}
    local down = Vector( 0, 0, 100000 )

    -- Big decal
    net.Receive( "lambdaplayers_sparta_decal", function()
        local pos = net.ReadVector()

        local mat = util_DecalMaterial( "Scorch" )
        local imat = Material( mat )

        tracetable.start = pos
        tracetable.endpos = pos - down
        tracetable.mask = MASK_SOLID_BRUSHONLY
        local result = Trace( tracetable ) 

        util_DecalEx( imat, Entity( 0 ), result.HitPos, result.HitNormal, color_white, 10,10 )
    end )


    -- Gray smoke
    net.Receive( "lambdaplayers_sparta_smoke", function()
        local pos = net.ReadVector()

        local emitter = ParticleEmitter( pos )

        for i = 1, 30 do
            local part = emitter:Add( "particle/SmokeStack", pos )
            if part then
                part:SetDieTime( 20 )
        
                part:SetStartAlpha( 255 )
                part:SetEndAlpha( 0 )
        
                part:SetColor( 50, 50, 50 )
        
                part:SetStartSize( 700 )
                part:SetEndSize( 700 )
        
                local vel = VectorRand() * 100
                vel.z  = abs( vel.z ) / 2
                part:SetVelocity( vel )
                part:SetAngleVelocity( AngleRand( -0.8, 0.8 ) )
            end
        end
        
        emitter:Finish()
    end )
end

table.Merge( _LAMBDAPLAYERSWEAPONS, {

    spartafists = {
        model = "",
        origin = "Garry's Mod",
        prettyname = "Sparta Fists",
        holdtype = "fist",
        killicon = "lambdaplayers/killicons/icon_fists",
        ismelee = true,
        nodraw = true,
        keepdistance = 15,
        attackrange = 70,

        callback = function( self, wepent, target )
            if CurTime() < self.l_WeaponUseCooldown then return end

            self.l_WeaponUseCooldown = CurTime() + 4

            -- THIS. IS. SPARTA!
            self:EmitSound( "lambdasparta/thisissparta.mp3", 90 )

            self:SimpleTimer( 1.8, function()
                if self:GetWeaponName() != "spartafists" then return end
                self:AddGesture( ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true )
            end )

            self:SimpleTimer( 2.1, function()
                if self:GetWeaponName() != "spartafists" then return end

                if LambdaIsValid( target ) and self:GetRangeSquaredTo( target ) <= ( 70 * 70) then
                    
                    wepent:EmitSound( "lambdasparta/punch.mp3", 90 )
                    sound_Play( "lambdasparta/stinger.mp3", Vector(), 0, 100, 1 )
                    ParticleEffect( "explosion_huge", self:GetPos(), Angle( 0, 0, 0 ) ) -- Explosion effect
                    util.ScreenShake( self:GetPos(), 400, 200, 7, 60000) -- Shake screens

                    local nearby = self:FindInSphere( nil, 1000, function( ent ) return ent != self end )


                    -- Damage all NPCs/Players and move props
                    for k, ent in ipairs( nearby ) do
                        if ent:IsNPC() or ent:IsPlayer() or ent:IsNextBot() then
                            local info = DamageInfo()
                            info:SetAttacker( self )
                            info:SetInflictor( wepent )
                            info:SetDamage( 10000000000 ) -- You shall die
                            info:SetDamageType( bit_bor( DMG_BLAST, DMG_CLUB ) )
                            local attackAng = ( target:WorldSpaceCenter() - self:EyePos() ):Angle()
                            local vel = ( attackAng:Forward() * ( 1000 * 200 ) + attackAng:Up() * ( 1000 * 200 ) )
                            info:SetDamagePosition( wepent:GetPos() )

                            if ent.IsLambdaPlayer then
                                ent.loco:Jump()
                                ent.loco:SetVelocity( ent.loco:GetVelocity() + ( vel * 0.01 ) )
                                timer.Simple(0.1, function()
                                    if !LambdaIsValid( ent ) then return end
                                    ent:TakeDamageInfo( info )
                                end)
                            else
                                info:SetDamageForce( vel )
                                ent:TakeDamageInfo( info )
                            end

                        else
                            local phys = ent:GetPhysicsObject()
                            if IsValid( phys ) then phys:ApplyForceCenter( self:GetNormalTo( ent ) * 100000000 ) end
                        end
                    end

                    -- Make the player's screen turn white for a bit after they have been punched
                    if target:IsPlayer() then target:ScreenFade( SCREENFADE.IN, color_white, 5, 2 ) end

                    -- Spark effects after the punch has connected
                    local endtime = CurTime() + 18
                    self:Hook( "Tick", "spartasparks", function()
                        if CurTime() > endtime then return "end" end

                        local effect = EffectData()
                        effect:SetOrigin( self:WorldSpaceCenter() + VectorRand( -self:GetModelRadius(), self:GetModelRadius() ) )
                        effect:SetMagnitude( 2 )
                        effect:SetScale( 1 )
                        effect:SetRadius( 200 )

                        sound_Play( "ambient/energy/spark" .. random( 1, 6 ) .. ".wav", self:WorldSpaceCenter() + VectorRand( -self:GetModelRadius(), self:GetModelRadius() ), 65, 100, 1 )

                        util_Effect( "Sparks", effect, true, true )
                        
                    end, false, 0.05 )

                    -- Place the large decal
                    net.Start( "lambdaplayers_sparta_decal" )
                    net.WriteVector( self:WorldSpaceCenter() )
                    net.Broadcast()

                    -- Emit Large smoke
                    net.Start( "lambdaplayers_sparta_smoke" )
                    net.WriteVector( self:WorldSpaceCenter() )
                    net.Broadcast()

                    -- Play a "reality shattering" effect
                    local tesla = ents.Create( "point_tesla" )
                    tesla:SetPos( self:EyePos() + Vector( 0, 0, 40) )
                    tesla:SetKeyValue( "m_SoundName", "DoSpark" )
                    tesla:SetKeyValue( "m_flRadius", "4000" )
                    tesla:SetKeyValue( "m_Color", "255 255 255" )
                    tesla:SetKeyValue( "texture", "sprites/physbeam.vmt" )
                    tesla:SetKeyValue( "thick_max", "40" )
                    tesla:SetKeyValue( "thick_min", "20" )
                    tesla:SetKeyValue( "beamcount_max", "20" )
                    tesla:SetKeyValue( "beamcount_min", "7" )
                    tesla:SetKeyValue( "interval_max", "6" )
                    tesla:SetKeyValue( "interval_min", "6" )
                    tesla:SetKeyValue( "lifetime_max", "10" )
                    tesla:SetKeyValue( "lifetime_min", "10" )
                    tesla:Spawn()
                    tesla:Activate()

                    tesla:Fire( "DoSpark" )

                    timer.Simple( 8, function() if IsValid( tesla ) then tesla:Remove() end end )


                    -- Say a cool line before returning to normal
                    self:GodEnable()
                    self:Freeze( true )

                    self:Thread( function()

                        coroutine.wait( 0.5 ) 

                        self:EmitSound( GetConVar( "lambdaplayers_sparta_aftertrack" ):GetString(), 90 )

                        coroutine.wait( 1 ) 

                        if random( 1, 100 ) <= self:GetTextChance() and self:CanType() then
                            self.l_keyentity = victim
                            self:TypeMessage( self:GetTextLine( "kill" ) )
                        elseif random( 1, 100 ) <= self:GetVoiceChance() then
                            self:PlaySoundFile( self:GetVoiceLine( "kill" ), true )
                        end

                        while self:GetIsTyping() or self:IsSpeaking() do coroutine.yield() end


                        coroutine.wait( 1 )

                        self:SwitchToRandomWeapon()
                        self:Freeze( false )
                        self:GodDisable()
                        
                    end, "spartaepicness", true )
                else

                    -- It missed. Now we'll have to pay the price
                    local effect = EffectData()
                    effect:SetOrigin( self:WorldSpaceCenter() )
                    util_Effect( "Explosion", effect, true, true ) 

                    local info = DamageInfo()
                    info:SetDamage( 0 )
                    info:SetDamageForce( VectorRand( -1000, 1000 ) )
                    info:SetAttacker( Entity( 0 ) )
                    info:SetDamagePosition( self:GetPos() )
                    self:LambdaOnKilled( info )

                end
            
            end )

            return true
        end,
        
        islethal = true
    }

})