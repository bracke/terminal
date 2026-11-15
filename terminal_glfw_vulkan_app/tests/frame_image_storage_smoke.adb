with Terminal.App.Renderer.Testing.Events;
with Terminal.App.Renderer.Testing.Frame_Storage;

procedure Frame_Image_Storage_Smoke is
begin
   Terminal.App.Renderer.Testing.Frame_Storage
     .Verify_Frame_Image_Storage_Invariants;
   Terminal.App.Renderer.Testing.Events.Verify_Event_Payload_Borrow_Guard;
end Frame_Image_Storage_Smoke;
