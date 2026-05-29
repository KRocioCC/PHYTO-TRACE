import argparse
import tensorflow as tf


def _load_model(model_path: str):
    try:
        return tf.keras.models.load_model(model_path, compile=False, safe_mode=False)
    except Exception as first_error:
        try:
            import keras

            return keras.models.load_model(model_path, compile=False, safe_mode=False)
        except Exception as second_error:
            try:
                return _rebuild_known_corn_model(model_path)
            except Exception as third_error:
                raise RuntimeError(
                    f"No se pudo cargar el modelo .h5 con tf.keras ni keras. "
                    f"tf.keras error: {first_error}; keras error: {second_error}; "
                    f"rebuild error: {third_error}"
                )


def _rebuild_known_corn_model(model_path: str):
    inputs = tf.keras.Input(shape=(224, 224, 3), name="input_layer_3")
    base = tf.keras.applications.MobileNetV2(
        include_top=False,
        weights=None,
        input_tensor=inputs,
    )
    x = tf.keras.layers.GlobalAveragePooling2D(name="global_average_pooling2d_1")(base.output)
    x = tf.keras.layers.Dropout(0.3, name="dropout_1")(x)
    x = tf.keras.layers.Dense(128, activation="relu", name="dense_2")(x)
    outputs = tf.keras.layers.Dense(4, activation="softmax", name="dense_3")(x)

    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="sequential_1")
    model.load_weights(model_path, by_name=True)
    return model


def convert(model_path: str, output_path: str, input_size: int):
    model = _load_model(model_path)

    concrete_function = tf.function(model).get_concrete_function(
        tf.TensorSpec([1, 224, 224, 3], tf.float32, name="input")
    )
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_function])
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    converter._experimental_lower_tensor_list_ops = True

    tflite_model = converter.convert()
    with open(output_path, "wb") as f:
        f.write(tflite_model)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--input-size", type=int, default=0)
    args = parser.parse_args()

    convert(args.input, args.output, args.input_size)
