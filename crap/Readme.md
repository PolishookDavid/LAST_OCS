This folder contains scripts and function which used to be in `+obs/+util/+config`
and `+obs/+util/+tools`. IMHO they don't deserve to be part class methods
(some don't even depend on classes), or of the LAST_OCS package at all.
Some are even orphans, in the sense that I found no callers for them or obvious reasons
for them to be called interactively.

They are temporarily put in this limbo before adaptation, relocation or deletion.