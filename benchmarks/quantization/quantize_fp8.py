from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "Qwen/Qwen2.5-7B-Instruct"
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

recipe = QuantizationModifier(targets="Linear", scheme="FP8_DYNAMIC", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)

model.save_pretrained("qwen2.5-7b-FP8-Dynamic", save_compressed=True)
tokenizer.save_pretrained("qwen2.5-7b-FP8-Dynamic")
print("DONE → qwen2.5-7b-FP8-Dynamic")
