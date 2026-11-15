package body Terminal.App.Vulkan_Queue_Selection is
   procedure Consider
     (State        : in out Choice;
      Index        : Natural;
      Has_Graphics : Boolean;
      Has_Present  : Boolean) is
   begin
      if State.Shared_Found then
         return;
      elsif Has_Graphics and then Has_Present then
         State.Graphics_Found := True;
         State.Present_Found := True;
         State.Graphics := Index;
         State.Present := Index;
         State.Shared_Found := True;
         return;
      end if;

      if Has_Graphics and then not State.Graphics_Found then
         State.Graphics_Found := True;
         State.Graphics := Index;
      end if;
      if Has_Present and then not State.Present_Found then
         State.Present_Found := True;
         State.Present := Index;
      end if;
   end Consider;

   function Complete (State : Choice) return Boolean is
     (State.Graphics_Found and then State.Present_Found);

   function Shared (State : Choice) return Boolean is
     (State.Shared_Found);

   function Graphics_Index (State : Choice) return Natural is
     (State.Graphics);

   function Present_Index (State : Choice) return Natural is
     (State.Present);
end Terminal.App.Vulkan_Queue_Selection;
