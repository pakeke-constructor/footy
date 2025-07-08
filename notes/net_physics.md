

# Net Physics


AMAZING ARTICLES:

https://gafferongames.com/post/introduction_to_networked_physics/

https://gafferongames.com/post/deterministic_lockstep/

https://gafferongames.com/post/snapshot_interpolation/
^^^ we probably want to use this one?



## Godot issue:
https://github.com/godotengine/godot-proposals/issues/2821
(^^^ REALLY GOOD READ!)




## How should we do this?

IDEA: Buffer inputs on client. Send immediately to server with frame-number; 
server will buffer them if latency is low, and apply immediately if latency is high

IDEA: Buffer inputs on client. Send immediately to server with frame-number.









