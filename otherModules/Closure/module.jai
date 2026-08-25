#module_parameters(MAX_PAYLOAD_SIZE := 64);

Closure :: struct {
    callback : #type (*Closure);
    payload  : [MAX_PAYLOAD_SIZE] u8;
}

call :: (using closure : *Closure) {
    callback(closure);
}

init :: (using closure : *Closure, proc : $T) {
    Payload_Wrapper :: struct (T: Type) {
        Payload  :: struct { cb: T; }
        callback :: (c: *Closure) { c.payload.data.(*Payload).cb(); }
    }

    W :: Payload_Wrapper(T);
    #assert size_of(W.Payload) <= MAX_PAYLOAD_SIZE "Closure payload too big. Raise MAX_PAYLOAD_SIZE.";

    p := payload.data.(*W.Payload);

    callback = W.callback;
    p.cb = proc;
}

init :: (using closure : *Closure, proc : $T, a1: $A1) {
    Payload_Wrapper :: struct (T: Type, A1: Type) {
        Payload  :: struct { cb: T; a1: A1; }
        callback :: (c: *Closure) { using c.payload.data.(*Payload); cb(a1); }
    }

    W :: Payload_Wrapper(T, A1);
    #assert size_of(W.Payload) <= MAX_PAYLOAD_SIZE "Closure payload too big. Raise MAX_PAYLOAD_SIZE.";

    p := payload.data.(*W.Payload);

    callback = W.callback;
    p.cb = proc; p.a1 = a1;
}

init :: (using closure : *Closure, proc : $T, a1: $A1, a2: $A2) {
    Payload_Wrapper :: struct (T: Type, A1: Type, A2: Type) {
        Payload  :: struct { cb: T; a1: A1; a2: A2; }
        callback :: (c: *Closure) { using c.payload.data.(*Payload); cb(a1, a2); }
    }

    W :: Payload_Wrapper(T, A1, A2);
    #assert size_of(W.Payload) <= MAX_PAYLOAD_SIZE "Closure payload too big. Raise MAX_PAYLOAD_SIZE.";

    p := payload.data.(*W.Payload);

    callback = W.callback;
    p.cb = proc; p.a1 = a1; p.a2 = a2;
}

init :: (using closure : *Closure, proc : $T, a1: $A1, a2: $A2, a3: $A3) {
    Payload_Wrapper :: struct (T: Type, A1: Type, A2: Type, A3: Type) {
        Payload  :: struct { cb: T; a1: A1; a2: A2; a2: A3; }
        callback :: (c: *Closure) { using c.payload.data.(*Payload); cb(a1, a2, a3); }
    }

    W :: Payload_Wrapper(T, A1, A2, A3);
    #assert size_of(W.Payload) <= MAX_PAYLOAD_SIZE "Closure payload too big. Raise MAX_PAYLOAD_SIZE.";

    p := payload.data.(*W.Payload);

    callback = W.callback;
    p.cb = proc; p.a1 = a1; p.a2 = a2; p.a3 = a3;
}