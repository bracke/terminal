package Terminal.App.Vulkan_Queue_Selection is
   type Choice is private;

   procedure Consider
     (State        : in out Choice;
      Index        : Natural;
      Has_Graphics : Boolean;
      Has_Present  : Boolean);

   function Complete (State : Choice) return Boolean;
   function Shared (State : Choice) return Boolean;
   function Graphics_Index (State : Choice) return Natural;
   function Present_Index (State : Choice) return Natural;

private
   type Choice is record
      Graphics_Found : Boolean := False;
      Present_Found  : Boolean := False;
      Graphics       : Natural := 0;
      Present        : Natural := 0;
      Shared_Found   : Boolean := False;
   end record;
end Terminal.App.Vulkan_Queue_Selection;
