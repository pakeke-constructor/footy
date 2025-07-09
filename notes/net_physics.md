

# Net Physics



AMAZING ARTICLES:
https://gafferongames.com/post/introduction_to_networked_physics/
https://gafferongames.com/post/deterministic_lockstep/
https://gafferongames.com/post/snapshot_interpolation/

Relevant Godot issue: https://github.com/godotengine/godot-proposals/issues/2821
(^^^ REALLY GOOD READ!)



# Net physics is HARD!!!
## How should we do this?


## IDEA 1: (BEST CURRENTLY)
IDEA: Don't move on client. 
Send input immediately to server with current-time; 

server will apply the movement 0.1 seconds after the player moved (100ms) 

This means that if you have 50ms or lower, your inputs will look the same.
If you have >50ms, your input will be delayed though, and you'll lag.

VERY IMPORTANT:
Make sure that response-feedback is still given INSTANTLY!!!
For example: 

When the player kicks the ball:
- A confirmation sound should play INSTANTLY (eg a woosh or something)
- Then, when the server responds, THATS when particles should fly.

When the player moves forward/back or strafes left/right,
- the player's model should lean that direction, and start stepping in that direction, 
    (instant feedback)
- Then, when the server responds, THATS when the player actually moves

PROBLEMS WITH THIS APPROACH:
- If the packet loss-rate is high, then there will be hitches; since it's all server-authoritative.

If we make the tickrate high, EG 64 ticks per second, it's probably not too bad though.
We would want different objects to tick at different rates too.
- If an object is close to the player, tick it at 64 TPS
- If an object is idle, or away from the "action", it should only tick at around 10 TPS maybe?
- Include delta-compression (super easy to do)

Other people have also had this idea:
https://docs-multiplayer.unity3d.com/netcode/1.9.1/advanced-topics/client-anticipation/



