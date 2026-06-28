from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import GPTQModifier
from datasets import load_dataset

MODEL_ID = "Qwen/Qwen2.5-7B-Instruct"
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

NUM_CALIB, MAX_SEQ = 512, 2048
ds = load_dataset("HuggingFaceH4/ultrachat_200k", split="train_sft")
ds = ds.shuffle(seed=42).select(range(NUM_CALIB))
ds = ds.map(lambda e: {"text": tokenizer.apply_chat_template(e["messages"], tokenize=False)})
ds = ds.map(lambda s: tokenizer(s["text"], padding=False, max_length=MAX_SEQ,
            truncation=True, add_special_tokens=False), remove_columns=ds.column_names)

recipe = GPTQModifier(targets="Linear", scheme="W4A16", ignore=["lm_head"])
oneshot(model=model, dataset=ds, recipe=recipe,
        max_seq_length=MAX_SEQ, num_calibration_samples=NUM_CALIB)

model.save_pretrained("qwen2.5-7b-W4A16", save_compressed=True)
tokenizer.save_pretrained("qwen2.5-7b-W4A16")
print("DONE → qwen2.5-7b-W4A16")
