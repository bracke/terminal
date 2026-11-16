with GLFW_Vulkan.Input;

package Terminal.App.Key_Bindings is
   type Action is
     (No_Action,
      Paste,
      Copy,
      Search,
      Copy_Mode,
      Open_Links,
      Command_Palette,
      New_Window,
      Detach_Tab,
      Reload_Config,
      Settings,
      Toggle_Pane_Zoom,
      Move_Pane,
      Broadcast_Input,
      Toggle_Recording,
      Replay_Recording,
      Export_Transcript,
      Previous_Mark,
      Next_Mark,
      Select_Command_Block,
      Copy_Command_Block,
      Rerun_Command_Block,
      Font_Increase,
      Font_Decrease,
      Font_Reset,
      New_Tab,
      Close_Tab,
      Next_Tab,
      Previous_Tab,
      Split_Horizontal,
      Split_Vertical,
      Close_Pane,
      Next_Pane);
   subtype Configurable_Action is Action range Paste .. Next_Pane;

   type Binding is record
      Key       : GLFW_Vulkan.Input.Key := GLFW_Vulkan.Input.Unknown;
      Modifiers : GLFW_Vulkan.Input.Modifier_Set := (others => False);
      Enabled   : Boolean := False;
   end record;
   type Binding_Set is array (Configurable_Action) of Binding;

   function Defaults return Binding_Set;
   function Parse (Text : String; Result : out Binding) return Boolean;
   function Image (Value : Binding) return String;
   function Action_For
     (Bindings : Binding_Set;
      Event    : GLFW_Vulkan.Input.Key_Event) return Action;
   function Action_Name (Value : Configurable_Action) return String;
   function Parse_Action_Name
     (Name   : String;
      Result : out Configurable_Action) return Boolean;
end Terminal.App.Key_Bindings;
